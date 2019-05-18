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

Beside, this tries to be a proper router OS with a goal overlapping
the OpenWRT LUCI project.

## Features

 * Auto manage the Intranet domain DNS
 * Try to give the same IP to each device when possible
 * Garbase collect old devices to clean the VLAN
 * Add a low effort firewall config
 * Offer an event driver, object oriented, Lua API into dnsmasq
 * Offer a Lua API for /sys and /proc network knobs
 
## Planned

 * Generate XML files for cisco phones
 * Generate payloads for some dev boards
 * Allow x86 PCs to boot from a list of ISOs
