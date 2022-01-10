## docker-routing

This container is a work-in-progress attempt to create a network
gateway for the other services. This is required both because
having a scriptable router is cool, but also because it is the
sanest way to support some PIM related hardware. A good use case
is uploading the correct config to hardware phones so they can
use the vCards and SIP system (to be added later in another
container).

Another use case is using boards such as many Raspberry PI 3 to
run each container.

In both case it requires PXE to work and generating some payloads
on-demand.

Automatic DNS and DNS-based service discovery also needs
to work.  Using Avahi/Bonjour, DHT or UPnP based discovery could
in theory offer a superior experience then DNS records, but the
later is better integrated and the former can be added later.

Beside, this tries to be a proper router OS with a goal overlapping
the (legacy) OpenWRT LUCI project. They are moving from Lua to pure
bash for the sake of making the image smaller. I think this is the
wrong solution: they should drop the shell and keep Lua. Yes, Lua
is larger than busybox ash, but having a large number of unreadable
bash scripts is a maintainability burden. It's also slower.

## Features

 * Auto manage the Intranet domain DNS
 * Try to give the same IP to each device when possible
 * Garbase collect old devices to clean the VLAN
 * Add a low effort firewall config
 * Offer an event driver, object oriented, Lua API into dnsmasq
 * Offer a Lua API for /sys and /proc network knobs
 
## Planned

 * Generate XML files for cisco and polycom phones
 * Generate PXE payloads for some dev boards
 * Allow x86 PCs to boot from a list of ISOs
 * Offer PXE menus to onboard hardware into a k8s cluster
 * Pry udhcpd, ifupdown and uhttpd off busybox and make
   Lua modules using dnsmasq event loop.
 * Remove Debian and use FROM:scratch without a shell or
   any other packages than musl, dnsmasq + Lua modules.
