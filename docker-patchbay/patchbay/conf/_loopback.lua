local module = {}

function module._to_xml()
    return [[<configuration name="logfile.conf" description="File Logging">
  <settings>
    <param name="rotate-on-hup" value="true"/>
  </settings>

  <profiles>
    <profile name="default">
      <settings>
        <!-- At this length in bytes rotate the log file (0 for never) -->
        <param name="rollover" value="10485760"/>
      </settings>

      <mappings>
        <!--
            name can be a file name, function name or 'all'
            value is one or more of debug,info,notice,warning,err,crit,alert,all
        -->
        <map name="all" value="debug,info,notice,warning,err,crit,alert"/>
      </mappings>
    </profile>
  </profiles>
</configuration>
]]
end

return module
