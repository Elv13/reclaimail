local module = {}

function module._to_xml()
    return [[<configuration name="syslog.conf" description="Syslog Logger">
    <!-- SYSLOG -->
    <!-- emerg   - system is unusable  -->
    <!-- alert   - action must be taken immediately  -->
    <!-- crit    - critical conditions  -->
    <!-- err     - error conditions  -->
    <!-- warning - warning conditions  -->
    <!-- notice  - normal, but significant, condition  -->
    <!-- info    - informational message  -->
    <!-- debug   - debug-level message -->
    <settings>
        <param name="facility" value="user"/>
        <param name="ident" value="freeswitch"/>
        <param name="loglevel" value="warning"/>
        <!-- log uuids in syslogs -->
        <param name="uuid" value="true"/>
    </settings>
    </configuration>
    ]]
end

return module
