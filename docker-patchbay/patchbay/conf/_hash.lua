local module = {}

function module._to_xml()
    return [[
    <configuration name="hash.conf" description="Hash Configuration">
  <remotes>
        <!-- List of hosts from where to pull usage data -->
        <!-- <remote name="Test1" host="10.0.0.10" port="8021" password="ClueCon" interval="1000" /> -->
  </remotes>
</configuration>
]]
end

return module
