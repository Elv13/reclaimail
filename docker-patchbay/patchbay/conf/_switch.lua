local module = {}

function module._to_xml()
    return [[<configuration name="switch.conf" description="Core Configuration">
    <settings>
        <param name="colorize-console" value="true"/>

        <!-- Max number of sessions to allow at any given time -->
        <param name="max-sessions" value="1000"/>
        <!--Most channels to create per second -->
        <param name="sessions-per-second" value="30"/>

        <!-- Default Global Log Level - value is one of debug,info,notice,warning,err,crit,alert -->
        <param name="loglevel" value="debug"/>

        <!-- RTP port range -->
        <param name="rtp-start-port" value="16384"/>
        <param name="rtp-end-port" value="32768"/>
    </settings>
    </configuration>]]
end

return module
