local common = require("patchbay.conf._common")

local HEADER = table.concat({
    '        <profile name="internal">',
    '            <aliases>',
    '            </aliases>',
    '            <gateways>',
    '            </gateways>',
    '            <domains>',
    '                <domain name="all" alias="true" parse="false"/>',
    '            </domains>',
    '            <settings>',
}, "\n")

local FOOTER = '            </settings>\n        </profile>'

-- From the default file.
local DEFAULTS = {
    ["debug"]  = "0",
    ["sip-trace"] = "no",
    ["sip-capture"] = "no",
    ["watchdog-enabled"] = "no",
    ["watchdog-step-timeout"] = "30000",
    ["watchdog-event-timeout"] = "30000",
    ["log-auth-failures"] = "false",
    ["forward-unsolicited-mwi-notify"] = "false",
    ["context"] = "public",
    ["rfc2833-pt"] = "101",
    ["sip-port"] = "$${internal_sip_port}",
    ["dialplan"] = "XML",
    ["dtmf-duration"] = "2000",
    ["inbound-codec-prefs"] = "$${global_codec_prefs}",
    ["outbound-codec-prefs"] = "$${global_codec_prefs}",
    ["rtp-timer-name"] = "soft",
    ["rtp-ip"] = "$${local_ip_v4}",
    ["sip-ip"] = "$${local_ip_v4}",
    ["hold-music"] = "$${hold_music}",
    ["apply-nat-acl"] = "nat.auto",
    ["apply-inbound-acl"] = "domains",
    ["local-network-acl"] = "localnet.auto",
    ["record-path"] = "$${recordings_dir}",
    ["record-template"] = "${caller_id_number}.${target_domain}.${strftime(%Y-%m-%d-%H-%M-%S)}.wav",
    ["manage-presence"] = "true",
    ["presence-hosts"] = "$${domain},$${local_ip_v4}",
    ["presence-privacy"] = "$${presence_privacy}",
    ["inbound-codec-negotiation"] = "generous",
    ["tls"] = "$${internal_ssl_enable}",
    ["tls-only"] = "false",
    ["tls-bind-params"] = "transport=tls",
    ["tls-sip-port"] = "$${internal_tls_port}",
    ["tls-passphrase"] = "",
    ["tls-verify-date"] = "true",
    ["tls-verify-policy"] = "none",
    ["tls-verify-depth"] = "2",
    ["tls-verify-in-subjects"] = "",
    ["tls-version"] = "$${sip_tls_version}",
    ["tls-ciphers"] = "$${sip_tls_ciphers}",
    ["inbound-late-negotiation"] = "true",
    ["inbound-zrtp-passthru"] = "true",
    ["nonce-ttl"] = "60",
    ["auth-calls"] = "$${internal_auth_calls}",
    ["inbound-reg-force-matching-username"] = "true",
    ["auth-all-packets"] = "false",
    ["ext-rtp-ip"] = "auto-nat",
    ["ext-sip-ip"] = "auto-nat",
    ["rtp-timeout-sec"] = "300",
    ["rtp-hold-timeout-sec"] = "1800",
    ["force-register-domain"] = "$${domain}",
    ["force-subscription-domain"] = "$${domain}",
    ["force-register-db-domain"] = "$${domain}",
    ["ws-binding" ] = ":5066",
    ["wss-binding"] = ":7443",
    ["challenge-realm"] = "auto_from",
}

local module = {
    object = common()
}

function module._to_xml()
    return common._to_xml(
        module.object, DEFAULTS, HEADER, FOOTER
    )
end

return module
