# Reclaim phone

This container is the brain to integrate SIP phones into reclaim.

## What

This is a softphone server software. It is middleware application for
the FreeSWITCH suite and other Reclaim sub-projects. FreeSWITCH was
selected over Asterisk because it seemed to have better support for high
level middleware and frontends. It has RPC, REST, REPL and official
script support beyond the dialplans.

This software provides an `rc.lua` to define what should happen when
some phone related events happen.

## Use case

Just like everything in Reclaim, the focus is on personal use case, not
corporate ones. This stack support one "person". If you need to run this
for a few people, then run multiple containers rather than try to handle
multi-users in this software.

## Glossary

Here is some jargon required to understand `rc.lua`.

 * **FreeSWITCH**: A server software to manage phone related protocols.
 * **inboud**: Call from *anything* to a FreeSWITCH server
 * **outbound**: Call from a FreeSWITCH server to anything (mostly bots and bridges)
 * **call leg**: Either "end" of the call. You or your peer
 * **peer**: The person/thing you are talking to, regardless of who called who
 * **bridge**: A call connecting >= 2 other calls. There is always a bridge.
 * **dialplan**: The actions taken when a call occurs
 * **SIP**: The most populkar VoIP protocol
 * **pstn**: The real international phone network
 * **did**: A SIP account attached to a"real" PSTN phone number
 * **extension**: A local phone number not routed on the PSTN
 * **device**: A physical or virtual "thing" attached to an extension
 * **rules**: AwesomeWM inspired condition engine to configure calls
 * **outage**: Anything that happen which can cause calls to fail
 * **directory**: A collection of endpoints (like a phonebook or LDAP)
 * **vCard/CardDAV**: Standard to store contact information
 * **iCal/CalDAV**: Standard to store events in a calendar
 * **recording**: Audio + metadata of a call, including voicemails
 * **registrar**: The entity which sits between the PSTN and FreeSWITCH
 * **REGISTER**: The action of renewing the connection between the registrar and a SIP account
 * **toll**: Some calls are free, some cost money, like long distance ones
 * **DTMF**: The sound it makes when you press a number key during a call (or dialing).
 * **dialing**: Inputing a phone number
 * **pickup**: When the call goes from ringing to active
 * **callerid**: The short peer name/string you see you see when you receive a call
 * **state**: Telem services are traditionally implemented as finite state machines.
 * **NAT**: Something IPv4 network routers do to map internal TCP/UDP ports to external ports.
 * **SPIT/SPAM**: The phone equivelent of SPAM (also known as robocalls).

## Goals / planned featuresc

Here is the list of features I plan to eventually have. The support code for
everything is already written, but not everything works.

 * [DONE] Ring multiple devices (cellphone, office phone and softphones) for the same call
 * [DONE] Manage you settings phone using `git`
 * [DONE] Play different voicemail intro messages intro based on whos calling
 * [DONE] Manage voicemail intros on a computer rather than phone menu
 * [DONE] Manage multiple spoken languages based on code and addressbook metadata
 * [DONE] Take calls on your computer with your normal computer headset
 * [DONE] Run random code on random phone events
 * [DONE] Make conferences, transfers and what not
 * [DONE] Route outgoing calls to the right number
 * [DONE] Share phone numbers across multiple physical locations
 * [DONE] Have multiple personal phone numbers for multiple homebase
   countries.
 * [DONE] Per device codecs
 * [DONE] Keep a readable/minimal non-developer log of the events
 * [USABLE] Run your own voicemail to email with speed-to-text and data mining
 * [USABLE] Somewhat manage/log downtimes and outages
 * [USABLE] Secured using WireGuard
 * [USABLE] Create special extension with phone menu to configure/access assets
 * [WIP] If/When a wifi call "cuts", retry to connect rather than
   hangup.
 * [TODO] Have your own phone bots, because why not
 * [TODO] Send email for missed calls, voicemail, etc
 * [TODO] Save the phone logs in CalDAV / iCal
    * [TODO] Keep audio recordings and transcripts in the calendar
 * [TODO] Integrate with vcard addressbooks
 * [TODO] Sync phone history between multiple devices
 * [TODO] Searcheable call history using speech-to-text
 * [TODO] Turn voice conversation into email threads
 * [TODO] Properly manage SMS/MMS as emails threads (including replies)
 * [TODO] Store images/video SMS (along with email attachments) into cloud directories
 * [TODO] Bridge to other systems chat sanely
 * [TODO] Renegotiate SIP-to-SIP calls as peer-to-peer rather than
   over the main PSTN trunk.
 * [NO] Have your own dial-up modems for the lol

## Scope

This is a full binding for the FreeSWITCH APIs. It controls
a subset of the FreeSWITCH modules by auto-generating their XML
config and injecting it over the network. It fully implements the
configuration, events, directory, chatplan and dialplan FreeSWITCH
extension APIs. The chatplan APIs will eventually be implemented.

## Inner working

See the `docker-freeswich` `README.md` for more details. At an
high level, FreeSWITCH already has Lua support built in. But they
run scripts on each events in their own Lua context, making it very
difficult to implement higher level products directly. FreeSWITCH
also has an XML-RPC API. The `patchbay` library created for this
Reclaim component uses ZeroMQ and the XML-RPC REST APIs to fully
wrap the "original" FreeSWITCH Lua APIs in a network-transparent
json-rpc data streams. It also extends FreeSWITCH with new API
events. Those API events are converted into async request/response
json-rpc messages.

`patchbay` executes everything in coroutines. Each request yield
the thread until the response arrives. This makes the `rc.lua`
fully parallel and non-blocking. Lua >= 5.2 is required. Lua 5.1
does not allow to mix `xpcall` and `coroutines`, which make it
very unstable. There is some groundwork to use the ZeroMQ event
loop, messages and (real) multi-thread APIs, but right now the
event loop only block on a single socket.

## Security

I advise to run FreeSWITCH behind a NAT with IPv6 disabled. This
requires more frequent pings and more frequent REGISTERs or your
NAT will unmap the connection and you wont receive calls. IPv6
is "fine", but has much more "features" than IPv4 and many of them
are very error prone to secure.

Rotate your registrar account passwords sanely. They are kept in
clear text because this is the only thing the registrar I have used
to far support. If your registrar supports TLS certificates, PKI
or oAuth, then patches welcome.

Do your security updates on the FreeSWITCH container. You still
get some network untrusted traffic from your devices, softphones
and registrars. If any of them get compromised, it will open an
escalation pathway toward FreeSWITCH, Docker and media players
(infected voicemails).

Store the settings, voicemail and SMS history on encrypted volumes.
They contain a lot of potentially sensitive personal information.

Plan for denial of service attacks on your registrar.

Use a VPN for any Android/iOS softphones.

Push your provider to support forwarding SHAKEN/STIR callerid security.

Use SIPS rather than SIP whenever possible, even if it means using
self-signed certificates.

Keep both the Patchbay and FreeSWITCH logs (on an excrypted volume)
for at least 3 months. They might contain data you will need when it
comes time to audit potential attacks.

## Usage

Read and modify `rc.lua`. It is where everything is defined. Then rebuild
the container. Don't forget to git-commit once in a while!

```sh
# Build
docker build . -t reclaim/patchbay

# Run
docker run --net host --rm -ti                   \
    -v $PWD/rc.lua:/rc.lua                       \
    -v $PWD/settings.json:/path/to/settings.json \
    elv13/phone                                  \
    lua /rc.lua
```

Here is a sample `settings.json`. The variables in the sample are used
by the default `rc.lua`. You can put any "secrets" which should not be
kept in `git`.

```json
{
    "device_count": 10,
    "device_password": "password",
    "voicemail_delay": 30,
    "emails": {
        /* Define emails for whatever role you want */
    },
    "caller_id": {
        "EN": "John Doe",
        "FR": "Jean Untel"
    },
    "dids": [
        {
             "gateway_name": "my_did_gateway1",
             "pstn_number": "1234567890",
             "username": "my_username",
             "password": "my_password",
             "proxy": "foo.example.com",
             "realm": "example.com",
             "domain": "example.com"
        }
    ]
}
```

Obviously, you need actual SIP credentials for this to work. Some
phone providers give them for free. Otherwise, you can buy some
for a few cents.
