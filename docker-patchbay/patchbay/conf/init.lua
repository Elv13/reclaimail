

return {
    acl              = require("patchbay.conf._acl"),
    event_socket     = require("patchbay.conf._event_socket"),
    post_load_switch = require("patchbay.conf._post_load_switch"),
    sofia            = require("patchbay.conf._sofia"),
    syslog           = require("patchbay.conf._syslog"),
    sip_profiles     = {
        internal = require("patchbay.conf._sip_profiles.internal"),
        external = require("patchbay.conf._sip_profiles.external"),
    }
}
