local module = {}


--TODO disable this nonsense
function module._to_xml()
    return [[<configuration name="conference.conf" description="Audio Conference">
  <advertise>
    <room name="3001@$${domain}" status="FreeSWITCH"/>
  </advertise>

  <caller-controls>
    <group name="default">
      <control action="mute" digits="0"/>
      <control action="deaf mute" digits="*"/>
      <control action="energy up" digits="9"/>
      <control action="energy equ" digits="8"/>
      <control action="energy dn" digits="7"/>
      <control action="vol talk up" digits="3"/>
      <control action="vol talk zero" digits="2"/>
      <control action="vol talk dn" digits="1"/>
      <control action="vol listen up" digits="6"/>
      <control action="vol listen zero" digits="5"/>
      <control action="vol listen dn" digits="4"/>
      <control action="hangup" digits="#"/>
    </group>
  </caller-controls>

  <profiles>
    <profile name="default">
      <param name="domain" value="$${domain}"/>
      <param name="rate" value="8000"/>
      <param name="interval" value="20"/>
      <param name="energy-level" value="100"/>
      <param name="muted-sound" value="conference/conf-muted.wav"/>
      <param name="unmuted-sound" value="conference/conf-unmuted.wav"/>
      <param name="alone-sound" value="conference/conf-alone.wav"/>
      <param name="moh-sound" value="$${hold_music}"/>
      <param name="enter-sound" value="tone_stream://%(200,0,500,600,700)"/>
      <param name="exit-sound" value="tone_stream://%(500,0,300,200,100,50,25)"/>
      <param name="kicked-sound" value="conference/conf-kicked.wav"/>
      <param name="locked-sound" value="conference/conf-locked.wav"/>
      <param name="is-locked-sound" value="conference/conf-is-locked.wav"/>
      <param name="is-unlocked-sound" value="conference/conf-is-unlocked.wav"/>
      <param name="pin-sound" value="conference/conf-pin.wav"/>
      <param name="bad-pin-sound" value="conference/conf-bad-pin.wav"/>
      <param name="caller-id-name" value="$${outbound_caller_name}"/>
      <param name="caller-id-number" value="$${outbound_caller_id}"/>
      <param name="comfort-noise" value="true"/>
    </profile>
  </profiles>
</configuration>
]]
end

return module
