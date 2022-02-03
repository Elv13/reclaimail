local module = {}

function module._to_xml()
    return [[<configuration name="post_load_modules.conf" description="Modules">
    <modules>
    </modules>
    </configuration>
    ]]
end

return module
