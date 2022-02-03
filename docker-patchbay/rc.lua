#!/usr/bin/lua
local session   = require("patchbay.session")
local directory = require("patchbay.directory")
local did       = require("patchbay.did")
local patchbay  = require("patchbay")
local logging   = require("logging")

--TODO check if the output goes to a terminal and disable colors.
local logger = patchbay.logging {
    name = "rc_lua"
}

-------------------------------
-- Some default call options.--
-------------------------------

-- Avoid storing passwords or identifying information in Git.
local secrets = patchbay.utils.decode_json_file("/settings.json")

-- Where to send the status updates.
local email_addresses = {
    sms    = os.getenv( "SMS_EMAIL_ADDRESS"    ),
    call   = os.getenv( "CALL_EMAIL_ADDRESS"   ),
    outage = os.getenv( "OUTAGE_EMAIL_ADDRESS" ),
}

-- Where the assets are stored.
patchbay.assets.sms.append_path("/sms")
patchbay.assets.recordings.append_path("/recordings")
patchbay.assets.ringtones.append_path("/ringtones")
patchbay.assets.voicemails.append_path("/voicemails")
patchbay.assets.voicemail_messages.append_paths({
    "/voicemail_messages",
    "/default_voicemail_messages",
})

-- The hangup will be called by this script to handle calls
-- with network problems.
patchbay.call.default_incoming_parameters.hangup_after_bridge = false
-- patchbay.call.default_incoming_parameters.auto_hangup = false
patchbay.call.default_incoming_parameters.playback_terminators = "none"

-- Ring normally on Cisco phones.
patchbay.call.default_incoming_parameters.ignore_early_media = true

-- This is the voicemail timeout.
patchbay.call.default_incoming_parameters.call_timeout = 30

-- Sometime the call can be salvaged. One of the reason this
-- project exist is to improve reliability.
patchbay.call.default_incoming_parameters.continue_on_fail = true
patchbay.call.default_outgoing_parameters.continue_on_fail = true

--TODO add some abstraction for this.
patchbay.call.default_outgoing_parameters.ringback = "us-ring"

-------------------------------------------------
-- Devices / directory / extensions management --
-------------------------------------------------
patchbay.directory.connect_signal("request::initialization", function()
    -- Create 10 devices. The word "device" is used in this context
    -- instead of extensions or directory. The reason is the the use
    -- case for this system isn't to manage a multi-department office,
    -- but rather to manage the multiple device a single person has.
    for idx = 1000, 1000 + secrets.device_count do
        -- Password rotation can be implemented for softphones (cron)
        -- or wired SIP phones (PXE), but it's not very convinient for
        -- Android without rooting the device. Maybe Reclaim needs a
        -- password manager...
        local device = patchbay.device {
            extension                  = tostring(idx),
            password                   = secrets.device_password .. tostring(idx),
            vm_password                = secrets.device_password .. tostring(idx),
            accountcode                = idx,
            effective_caller_id_name   = "Dev " .. idx,
            effective_caller_id_number = tostring(idx),
            toll_allow                 = {
                area          = true,
                international = true,
                domestic      = true,
            },
        }

        directory.add_device(device)
    end

    -- Handle multiple phone numbers. This is useful for expats
    -- and for people who have a different businesss and personal
    -- phone number.
    --
    -- It is also convinient if you are moving to a new area, want
    -- a local number but want to keep the old ones for
    -- two factor authentification security purpose.
    --
    -- Keep the `ping` value rather low if you are running this behind
    -- a NAT to avoid the connection beging garbage collected by your
    -- router. If port forwarding is used on the public internet (at
    -- your own risk), then 300 for the ping and 3600 for the register.
    for _, account in ipairs(secrets.dids or {}) do
        directory.add_did ( patchbay.did {
            gateway_name   = account.gateway_name,
            phone_number   = account.pstn_number,
            username       = account.username,
            password       = account.password,
            proxy          = account.proxy,
            realm          = account.realm,
            from_domain    = account.domain,
            sip_cid_type   = "rpid",
            register       = true,
            expire_seconds = 60,
            ping           = 20,
            retry_seconds  = 10,
        })
    end

    -- Register some call bots. They are just normal extensions
    -- bridged into every call. To implement your own bot, just
    -- take any automatable SIP client and connect to FreeSWITCH
    -- using the `extension` as username and `password` as password.
    --patchbay.bot {
    --    name      = "mycroft.ai",
    --    extension = 9999,
    --    passwork  =
    --}

    --patchbay.bot {
    --    name      = "gnujami_p2p_renegotiate",
    --    extension = 9998,
    --}

    --patchbay.bot {
    --    name      = "repeat_bot",
    --    extension = 9997,
    --}

    --patchbay.bot {
    --    name      = "rickroll",
    --    extension = 9996,
    --}
end)

patchbay.device.connect_signal("registered", function(d)
    logger.info("Device " .. d.extension .. " is now available.")
end)


-------------------------
-- History and logging --
-------------------------

-- When there is no device to pickup the call and/or the
-- call is not picked up after a delay.
patchbay.call.connect_signal("request::voicemail", function(c)
    --TODO handle pickup up while the voicemail is being
    -- recorded.
    for _, sibling in ipairs(c.bridged_siblings) do
        sibling:hangup() --TODO remove
    end

    c.missed = true

    logger:info("Play voicemail to " .. c.peer_number)
    c:answer()

    c:wait_until_media()

    logger:info(
        "Streaming file " .. c.voicemail .. " to " .. c.peer_number
    )

    if c.state == "HANGUP" or not c.voicemail then
        c.missed = true
        return
    end

    -- 8000 is for 8kHz, most codecs wont like anything higher.
    c:stream_file(c.voicemail, 8000)

    -- The `max_len_secs` is important to get rid of butt-dial recordings.
    local recording = patchbay.recording {
        call              = c,
        --path            = "/tmp/voicemail.wav",
        type              = "voicemail",
        max_len_secs      = 300,
        silence_threshold = 30,
        silence_secs      = 10,
    }

    recording:start()

    c:wait_until_hangup()

    --TODO finish
end)

-- Called when a new recoding is created.
patchbay.recording.connect_signal("finished", function(rec)
    -- Ultra short voicemails are just people hanging-up, discard them.
    if rec.type == "voicemail" and rec.duration < 2 then return end

    --TODO datamine
    logger:info("A new recording is available at " .. rec.path)
end)


-----------------
-- Call events --
-----------------

-- When someone else calls you.
patchbay.call.connect_signal("request::dialplan::external", function(c)
    -- Wait to see if one of the device pickup the call.e
    patchbay.utils.msleep(secrets.voicemail_delay * 1000)

    -- Timeout, redirect to voicemail.
    if c.state == "RINGING" then
        logger:warn(
            "declined call from " .. c.peer_number
            .. " because it wasn't picked up"
        )
        c:decline()
    end
end)

-- When you call someone else.
patchbay.call.connect_signal("request::dialplan::internal", function(c)
    local did = c.did or patchbay.directory.get_preferred_did()

    logger:info("Outgoing call to ".. c.destination_number, c.uuid)

    assert(c.did_number ~= c.destination_number, "Really bad")
end)

-- When an incoming call arrives, it is bridged to "new" calls
-- between FreeSWITCH and a device. This is the handler for those
-- sub-calls.
patchbay.call.connect_signal("request::dialplan::bridge", function(c)
    c:wait_until_hangup()
    --TODO when a call cuts, retry to connect to local devices

    logger:info("A bridge hung-up due to " .. c.hangup_cause)
end)

-- When the call finishes after being answered *or* gedt to the voicemail.
patchbay.call.connect_signal("state::hangup", function(c, old_state)
    if c.hangup_cause == "other_pickup" then return end

    logger:info(
        "The call between " .. c.peer_number .. " and "
        .. c.did_number .. " finished due to " .. c.hangup_cause
    )

    -- Hanhup the unused bridges.
    for _, sibling in ipairs(c.bridged_siblings) do
        logger:info(
            "Hangup the bridge between " .. sibling.peer_number
            .. " and " .. sibling.did_number
        )
        sibling:hangup()
    end

    --TODO get QoS stats, somehow

    --TODO add to flat history
    --TODO create calendar event
end)

-- Called when the peers are ready to talk to each other.
patchbay.call.connect_signal("state::active", function(c)
    logger:info("The call from " .. c.caller_id_number .. " is now ongoing")

    if c.direction == "incoming" and c.did then
        for _, sibling in ipairs(c.bridged_siblings) do
            if sibling.state == "RINGING" then
                sibling:hangup("other_pickup")
            end
        end
    end

    local recording = patchbay.recording {
        call = c,
        type = "session",
    }

    recording:start()
end)

-- When a peer calls you and hangup before it gets to the voicemail.
patchbay.call.connect_signal("missed", function(c)
    logger:warn("Missed call from " .. c.caller_id_number)
    --TODO send email

    for _, sibling in ipairs(c.bridged_siblings) do
        logger:warn(
            "Hangup the bridge between " .. sibling.peer_number
            .. " and " .. sibling.did_number
            .. " because the call was missed"
        )
        sibling:hangup()
    end
end)

-- Called when the peer respond as being busy.
-- This usually happen when they have a single line and are
-- already on a call.
patchbay.call.connect_signal("peer::busy", function(c)
    for _, sibling in ipairs(c.bridged_siblings) do
        logger:warn(
            "Hangup the bridge between " .. sibling.peer_number
            .. " and " .. sibling.did_number
            .. " because there is already a call in progress"
        )
        c:hangup("USER_BUSY")
    end
end)

-- When either peer press a button on the phone.
session.connect_signal("call::dtmf", function(c, data)
    logger:info("Received " .. tostring(data) .. " from " .. c.caller_id_number)
end)


----------------
-- Call rules --
----------------

patchbay.rules.call.connect_signal("request::rules", function()
    -- Default for external inbound call.
    patchbay.rules.call.append_rule {
        id = "external_calls_with_device",
        rule = {
            origin = "external",
        },
        rule_greater = {
            device_count = 0
        },
        properties = {
            record    = true,
            bridge_to = function()
                return directory.registered_devices
            end,
            bias_country = function(c)
                return c.did.bias_country
            end,
            language = function(c, props)
                return (c.country == "FR" or c.location == "Quebec") and "FR" or "EN"
            end,
            voicemail = function(c, props)
                local language = props.language or c.language

                return patchbay.assets.voicemail_messages.get("wave_"..language..".wav")
                    or patchbay.assets.voicemail_messages.get("wave.wav")
            end
        }
    }

    -- Default for internal inbound calls (calls from local device to FreeSWITCH).
    patchbay.rules.call.append_rule {
        id   = "all_internal_calls",
        rule = {
            origin = "internal",
        },
        properties = {
            record    = true,
            language = function(c, props)
                return (c.country == "FR" or c.location == "Quebec") and "FR" or "EN"
            end,
            caller_id = function(c)
                return secrets.caller_id[c.language]
                    or secrets.caller_id[c.language]["EN"]
            end,
            bridge_to = function(c)
                return patchbay.directory.get_preferred_did {
                    country = c.country,
                    --TODO somehow plug the contacts to avoid switching DID when calling back
                }
            end
        },
    }

    -- Decline (send to voicemail) forein calls during the night.
    -- Either its spam/spit or it's someone making a typo/buttdial.
    patchbay.rules.call.append_rule {
        id   = "spam_filter",
        rule = {
            origin = "external",
            time_interval = {
                begins = 2200,
                ends   = 0700,
            },
        },
        except_any = {
            country = {"CA", "US"}
        },
        properties = {
            decline = true,
        },
        callback = function(c)
            logger:warn("Declined call from " .. c.peer_number
                .. " because it is likely SPAM/SPIT"
            )
        end
    }

    -- When there is no connected device, decline and play a special voicemail.
    patchbay.rules.call.append_rule {
        id   = "no_devices_registered",
        rule = {
            origin       = "external",
            device_count = 0,
        },
        properties = {
            decline   = true,
            voicemail = function(c, props)
                local language = props.language or c.language

                return patchbay.assets.voicemail_messages.get("away_"..language..".wav")
                    or patchbay.assets.voicemail_messages.get("away.wav")
            end
        },
        callback = function(c)
            logger:warn("Declined call from " .. c.peer_number
                .. " because there is no device to pick it up."
            )
        end
    }

    -- Play a different voicemail when busy.
    --TODO give option to receive SMS when no longer busy
    patchbay.rules.call.append_rule {
        id   = "busy",
        rule = {
            origin = "external",
            busy   = true,
        },
        properties = {
            decline   = true,
            voicemail = function(c, props)
                local language = props.language or c.language

                return patchbay.assets.voicemail_messages.get("busy_"..language..".wav")
                    or patchbay.assets.voicemail_messages.get("busy.wav"
            end
        },
        callback = function(c)
            logger:warn("Declined call from " .. c.peer_number
                .. " because there is already a call in progress."
            )
        end
    }

    -- Special extention to record voicemails.
    patchbay.rules.call.append_rule {
        id   = "manage_voicemails",
        rule = {
            origin      = "internal",
            peer_number = "*86"
        },
        properties = {
            dialplan = function(c)
                while true do
                    if c.state == "HANGUP" then return end

                    c:say(table.concat({
                        "To listen to voicemails, press 1.",
                        "To record a voicemail, press 2"
                    }, " "))

                    local code = c:get_dtmf(1, 10000)

                    if code == 1 then
                        --TODO
                    elseif code == 2 then
                        local menu = {
                            action = {"listen to voicemails", "record a voicemail", "manage do not disturb"},
                            lang   = {"english", "french"},
                            dp     = {"default", "busy", "do not disturb"},
                        }

                        --TODO
                    end
                end
            end
        }
    }
end)

patchbay.rules.call.connect_signal("rule::match", function(c, rule)
    logger:info(
        "Call between " .. c.peer_number .. " and "
        .. c.did_number .. " matches rule " .. tostring(rule.id)
    )
end)


--------------------
-- Error handling --
--------------------

-- There are outages for the following:
--
--  * outage.network_incident: When the network (internet or intranet) goes down.
--  * outage.did_incident    : When a gateway/registrar goes down.
--  * outage.call_incident   : When a call cuts.
--  * outage.pbx_incident    : When FreeSWITCH stops responding.
--  * outage.device_incident : When a phone disconnects or timeout from FreeSWITCH
--  * outage.patchbay_incient: When a Lua error occurs.
--
-- Note that `indidents` are a tree. A network outage causes everything
-- else to go down with it.
--
-- Relclaim patchbay uses its `patchbay.incident` class to
-- track outages across multiple signal and object.
local email_template = [[
## System status

Patchbay is experiencing an ${meta_state} outage since in the ${component}
module.

It started at ${start_date} and the latest update came at
${update_date}. The last green state was at ${last_green_state_date}.

## Outage information

${summary}

## Updates

${update_bullets}

## Recent outages

${recent_outage_table}

]]

patchbay.outage.connect_signal("outage::begin", function(incident)
    logger:log(logging[incident.severity],
        "Outage begins " .. incident.type .. "\n" .. tostring(incident.summary)
    )
end)

patchbay.outage.connect_signal("outage::updated", function(incident)
    logger:log(logging[incident.severity],
        "Outage update " .. incident.type .. "\n" .. tostring(incident.summary)
    )
end)

patchbay.outage.connect_signal("outage::end", function(incident)
    if incident.state == "FAILURE" and incident.type == "CALL" then
        --TODO send SMS to apologize
    end

    logger:log(logging[incident.severity],
        "Outage ended " .. incident.type .. " lasted "
            .. tostring(incident.duration) .. " \n"
            ..  tostring(incident.summary)
        )
end)

-- This outage happens when the network interface goes down
patchbay.network.connect_signal("state::down", function(incident)
    --TODO start an outage report
end)

patchbay.network.connect_signal("state::up", function(incident)
    --TODO retry stuff
    --TODO send an incident report email
end)

-- This is called to handle Lua errors in Patchbay and in FreeSWITCH.
-- Patchbay is mostly async, so multiple execution routines (threads)
-- live in parallel.
patchbay.connect_signal("debug::error", function(err, co_traceback, remote_traceback)
    local summary = {}
    table.insert(summary, "\n = ERROR = \t" .. err)

    if co_traceback then
        for line in co_traceback:gmatch("([^\n]+)") do
            table.insert(summary, " > local >\t" .. line)
        end
    end

    if remote_traceback then
        for line in remote_traceback:gmatch("([^\n]+)") do
            table.insert(summary, " < remote <\t" .. line)
        end
    end

    table.insert(summary, "")

    summary = table.concat(summary, "\n")

    -- Create an outgage report to increase the visibility.
    patchbay.outage.patchbay_incident {
        severity         = "ERROR",
        summary          = summary,
        error            = err,
        local_traceback  = co_traceback,
        remote_traceback = remote_traceback,
    }
end)


----------------
-- SMS events --
----------------

-- >>>>> This section is not currently "really" implemented. <<<<<

session.connect_signal("sms::incoming", function(msg)
    --TODO wait for a little while to try to group the SMS into
    -- larger messages.

    --TODO detect the thread
    --TODO send email with reply_to
    --TODO setup the email server MTA to reply to the SMS
end)


--TODO call reloadxml
logger:info("Started")
session.start()

--TODO handle federation/thunks with other users.
