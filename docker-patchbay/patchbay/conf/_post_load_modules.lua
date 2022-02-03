local module = {}

function module._to_xml()
    return [[<configuration name="db.conf" description="LIMIT DB Configuration">
  <settings>
    <!--<param name="odbc-dsn" value="dsn:user:pass"/>-->
  </settings>
</configuration>
]]
end

return module
