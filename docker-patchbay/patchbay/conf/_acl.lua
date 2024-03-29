local module = {}

function module._to_xml()
    return [[<configuration name="acl.conf" description="Network Lists">
    <network-lists>
        <!--
            These ACL's are automatically created on startup.

            rfc1918.auto  - RFC1918 Space
            nat.auto      - RFC1918 Excluding your local lan.
            localnet.auto - ACL for your local lan.
            loopback.auto - ACL for your local lan.
        -->

        <list name="domains" default="deny">
        </list>
    </network-lists>
    </configuration>]]
end

return module
