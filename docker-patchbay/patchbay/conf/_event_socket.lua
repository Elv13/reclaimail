
local module = {}

function module._to_xml()
    return [[<configuration name="event_socket.conf" description="Socket Client">
    <settings>
        <param name="nat-map" value="false"/>
        <param name="listen-ip" value="127.0.0.1"/>
        <param name="listen-port" value="8021"/>
        <param name="password" value="ClueCon"/>
    </settings>
    </configuration>]]
end

return module