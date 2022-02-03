--- This module generates the XML file for the `sip_accounts` directory.
local rest         = require("rest")
local object       = require("patchbay.object")
local transaction  = require("patchbay._transaction")
local did_incident = require("patchbay.outage.did_incident")
local logging      = require("patchbay.logging")

local logger = logging {
    name = "did"
}

local module = {}

local ipv4_address = nil

local non_config_options = {
    gateway_name = true,
}

-- Generated using:
-- curl https://freeswitch.org/confluence/display/FREESWITCH/Sofia+Configuration+Files | xmllint --html --format - 2> /dev/null | grep mw-head | grep -Eo '>([^>]+)</span' | cut -f2 -d" " | grep \- | xargs -i -n1 echo '"    {}",'
local sofia_formatter = {
    "shutdown-on-fail",
    "user-agent-string",
    "sip-trace",
    "sip-port",
    "sip-ip",
    "ext-rtp-ip",
    "ext-sip-ip",
    "tcp-keepalive",
    "tcp-pingpong",
    "tcp-ping2pong",
    "resume-media-on-hold",
    "bypass-media-after-att-xfer",
    "bypass-media-after-hold",
    "inbound-bypass-media",
    "inbound-proxy-media",
    "disable-rtp-auto-adjust",
    "ignore-183nosdp",
    "enable-soa",
    "t38-passthru",
    "inbound-codec-prefs",
    "outbound-codec-prefs",
    "codec-prefs",
    "inbound-codec-negotiation",
    "inbound-late-negotiation",
    "disable-transcoding",
    "renegotiate-codec-on-reinvite",
    "ext-rtp-ip",
    "ext-sip-ip",
    "stun-enabled",
    "stun-auto-disable",
    "apply-nat-acl",
    "aggressive-nat-detection",
    "suppress-cng</span",
    ">NDLB-force-rport</span",
    "NDLB-broken-auth-hash</span",
    "NDLB-received-in-nat-reg-contact</span",
    "NDLB-sendrecv-in-session</span",
    "NDLB-allow-bad-iananame</span",
    "inbound-use-callid-as-uuid",
    "outbound-use-uuid-as-callid",
    "tls-only",
    "tls-bind-params",
    "tls-sip-port",
    "tls-cert-dir",
    "tls-version",
    "tls-passphrase",
    "tls-verify-date",
    "tls-verify-policy",
    "tls-verify-depth",
    "tls-verify-in-subjects",
    "rfc2833-pt</span",
    "dtmf-duration",
    "dtmf-type</span",
    "liberal-dtmf</span",
    "session-timeout",
    "enable-100rel",
    "minimum-session-expires",
    "sip-options-respond-503-on-busy",
    "sip-force-expires",
    "sip-expires-max-deviation",
    "outbound-proxy",
    "send-display-update",
    "auto-jitterbuffer-msec",
    "rtp-timer-name",
    "rtp-rewrite-timestamps",
    "rtp-autoflush-during-bridge",
    "rtp-autoflush",
    "challenge-realm",
    "accept-blind-auth",
    "auth-calls",
    "log-auth-failures",
    "auth-all-packets",
    "disable-register",
    "multiple-registrations",
    "max-registrations-per-extension",
    "accept-blind-reg",
    "inbound-reg-force-matching-username",
    "force-publish-expires",
    "force-register-domain",
    "force-register-db-domain",
    "send-message-query-on-register",
    "unregister-on-options-fail",
    "nat-options-ping",
    "all-reg-options-ping",
    "registration-thread-frequency",
    "inbound-reg-in-new-thread",
    "force-subscription-expires",
    "force-subscription-domain",
    "manage-presence",
    "presence-hold-state",
    "presence-hosts",
    "presence-privacy",
    "send-presence-on-register",
    "caller-id",
    "pass-callee-id",
    "hold-music",
    "disable-hold",
    "apply-inbound-acl",
    "apply-register-acl",
    "apply-proxy-acl",
    "record-template",
    "max-proceeding",
    "bind-params",
    "disable-transfer",
    "manual-redirect",
    "enable-3pcc",
    "nonce-ttl",
    "sql-in-transactions",
    "odbc-dsn",
    "mwi-use-reg-callid",
}

-- curl https://freeswitch.org/confluence/display/FREESWITCH/Sofia+Gateway+Authentication+Params | xmllint --html --format - 2> /dev/null | grep -oE '<strong>[^<]+' | cut -f2 -d '>' | xargs -i -n1 echo '"    {}",'
local gateway_formmatter = {
    "register",
    "schema",
    "realm",
    "username",
    "auth-username",
    "password",
    "caller-id-in-from",
    "extension",
    "extension-in-contact",
    "proxy",
    "context",
    "expire-seconds",
    "retry-seconds",
    "from-user",
    "from-domain",
    "register-proxy",
    "contact-params",
    "register-transport",
    "outbound-proxy",
    "proxy",
    "realm",
    "ping",
    "ping-max",
    "ping-min",
    "suppress-cng",
    "cid-type",
}

--- The main spoken language for this DID.
-- @property language
-- @tparam string
-- @see call.language

--- The bias country for thid did.
--
-- This affects how libphonenumber parses numbers.
--
-- @property bias_country
-- @tparam string bias_country 2 letter country code
--
-- @see call.bias_country

-- Make some attribute usable as Lua properties.
for i= #gateway_formmatter, 1, -1 do
    local key = gateway_formmatter[i]
    local newkey = key:gsub("-", "_")
    gateway_formmatter[i] = nil
    gateway_formmatter[newkey] = key

    module["set_"..newkey] = function(self, value)
        self._private.config[key] = value
        --TODO pending reloadxml
    end
end

--- The DID unformatted phone number.
-- @property phone_number

function module:get_phone_number()
    return self._private.phone_number
end

--- The DID with libphonenumber formatting.
-- @property formatted_phone_number

function module:get_formatted_phone_number()
    --TODO
end

--- Bridge an existing call to this device.
-- @method bridge_call
-- @tparam patchbay.call c The call.

local function bridge_callback(...)
    --TODO
end

function module:bridge_call(c)
    logger:info("Bridging "..self._private.gateway_name.." to "..c.destination_number)

    ipv4_address = ipv4_address
        or transaction.async_freeswitch_call("getGlobalVariable", "local_ip_v4")

    local pathway = "sofia/gateway/"..self._private.gateway_name.."/" .. c.destination_number

    local args = {
        call_uuid     = c.uuid,
        local_gateway = pathway
    }

    local internal_gateway_path = "sofia/external/"..c.destination_number

    require("patchbay.session")._register_pending_bridge {
        sibling               = c,
        parent_uuid           = c.uuid,
        external_gateway_path = args.local_gateway,
        internal_gateway_path = internal_gateway_path,
        local_gateway         = args.local_gateway,
        did                   = self,
        destination           = c.destination_number,
    }

    transaction.detached_script(bridge_callback, "bridge_device.lua", args)

    --TODO check every few seconds, maybe the device is dead and we don't know]]
end


-- Generate the sip_account/gateway
function module:_to_xml()
    local gateway_name = self._private.gateway_name or self.phone_number
    local params = {}

    for k, v in pairs(self._private.config) do
        if not non_config_options[k] then
            table.insert(
                params,
                '                   <param name="'..k..'" value="'..tostring(v)..'" />'
            )
        end
    end

    return table.concat({
        '                <gateway name="'..gateway_name..'">',
                table.concat(params, "\n"),
        '                </gateway>',
    }, "\n")
end

function module:_set_ping_status(state)
    if ping_status == "UP" then
        --
    elseif ping_status == "DOWN" then
        --
    end
end

--- Force a manual registration now.
-- @method register

function module:register()
    transaction.async_api_call("executeString", "sofia profile external register "..self.gateway_name)
end

--- Manually unregister now.
-- @method unregister

function module:unregister()
    transaction.async_api_call("executeString", "sofia profile external unregister "..self.gateway_name)
end

--- The did state.
--
-- * NEW
-- * REGISTER
-- * REGED
-- * DOWN
-- * FAIL_WAIT
-- * FAILED
-- * UNREGED
-- * TRYING
--
-- @property state
-- @tparam string

function module:get_state()
    -- Actually block for this one. Otherwise co-routines will pile up.
    -- It will only happen during initialization.
    if (self._private.state or "NEW") == "NEW" then
        local gateway_name = self._private.gateway_name or self.phone_number

        local result = rest.plain_text_command(
            "sofia status gateway external::"..gateway_name
        )

        for line in result:gmatch("([^\n]+)") do
            local k, v = line:match("^([^ \t]+)[ \t]+(.*)")

            if k == "State" then
                self._private.state = v
                return self._private.state
            end
        end
    end

    return self._private.state
end

local actions = {}

function actions.start_outage(self)
    -- The TRYING transitions can cause this to happen.
    if self._private.current_outage then
        return actions.update_outage(self)
    end

    --TODO
    self._private.current_outage = did_incident {
        did = self
    }

    self._private.current_outage:confirm_outage()
end

function actions.end_outage(self)
    if not self._private.current_outage then return end

    self._private.current_outage:confirm_recovery()

    self._private.current_outage = nil
end

function actions.update_outage(self)
    self._private.current_outage:confirm_update()
end

-- Ignore the TRYING change when NEW to avoid creating outages for nothing.
-- Ignore the REGED -> REGISTER refresh. It's noise.
function actions.noop(self, prev)
    self._private.state = prev
end

local meta_state = {
    NEW        = "DOWN",
    REGISTER   = "DOWN",
    REGED      = "UP",
    DOWN       = "DOWN",
    FAIL_WAIT  = "DOWN",
    FAILED     = "DOWN",
    UNREGED    = "DOWN",
    TRYING     = "DOWN",
}

local state_machine = {
    NEW       = {REGISTER = nil   , REGED = nil         , DOWN = "start_outage" , FAIL_WAIT = "start_outage" , FAILED = "start_outage" , UNREGED = "start_outage", TRYING = "noop"},
    REGISTER  = {REGISTER = nil   , REGED = "end_outage", DOWN = nil            , FAIL_WAIT = nil            , FAILED = nil            , UNREGED = nil           , TRYING = nil   },
    REGED     = {REGISTER = "noop", REGED = nil         , DOWN = "start_outage" , FAIL_WAIT = "start_outage" , FAILED = "start_outage" , UNREGED = "start_outage", TRYING = nil   },
    DOWN      = {REGISTER = nil   , REGED = "end_outage", DOWN = nil            , FAIL_WAIT = nil            , FAILED = nil            , UNREGED = nil           , TRYING = nil   },
    FAIL_WAIT = {REGISTER = nil   , REGED = "end_outage", DOWN = nil            , FAIL_WAIT = nil            , FAILED = nil            , UNREGED = nil           , TRYING = nil   },
    FAILED    = {REGISTER = nil   , REGED = "end_outage", DOWN = nil            , FAIL_WAIT = nil            , FAILED = nil            , UNREGED = nil           , TRYING = nil   },
    UNREGED   = {REGISTER = nil   , REGED = "end_outage", DOWN = nil            , FAIL_WAIT = nil            , FAILED = nil            , UNREGED = nil           , TRYING = nil   },
    TRYING    = {REGISTER = nil   , REGED = "end_outage", DOWN = "start_outage" , FAIL_WAIT = "start_outage" , FAILED = "start_outage" , UNREGED = nil           , TRYING = nil   },
}

function module:_set_state(state)
    local old_state = self.state or "NEW"

    -- Happen when you restart Patchbay with a running FreeSWITCH
    if self._private.current_outage and meta_state[old_state] == "DOWN" then
        actions.start_outage(self)
    end

    self._private.state = state

    if old_state then
        if (not state_machine[old_state]) then
            logger:error("Unexpected state change between "..tostring(old_state) .. " and " .. state)
        else
            local f_name = state_machine[old_state][state]

            if f_name then
                actions[f_name](self, old_state)
            end
        end
    end

    if self.state ~= old_state then
        self:emit_signal("property::state", self.state, old_state)
        self:emit_signal("state::"..self.state:lower(), old_state)
    end
end

local function new(_, args)
    args = args or {}

    assert(args.phone_number, "The DID needs a `phone_number` constructor attribute")

    local ret = object {
        class = module
    }

    ret._private.config = {}
    ret._private.state = "NEW"

    ret._private.phone_number = args.phone_number

    object.apply_args(ret, args)

    return ret
end

return object.patch_table(module, {
    is_module = true,
    call      = new
})
