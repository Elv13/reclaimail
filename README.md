RecaiMail: Get eMail under your control
=======================================

This project aims to allow to make a local copy of some web services like
GMail, Calendars, Contacts, DNS and SIP. It does so with micro services to
handle what would otherwise require the service. It is used to assemble my
own "smart home router" OS.

## How

Thunderbird, KMail, KubeMail, Evolution and other open solutions exists. Plus
a lot of large groupewares like Zimbra and Kolab. They are good at what they
do, but their size and constant threats of development shutdown / sunsetting
don't seem to give a nice foundation to start a migration away from GMail.

ReclaiMail fixes this by assembling many small and easily replaceable projects
together with some simple glue (mostly written in Lua) and bundling them in
Linux containers. If a project dies, then another one can take its place with
only minor changes to the glue layer.

To make the transition easier, it also fully support GMail, including mirroring
the data locally and translating the filters and applying them locally. By
comparing the result of the local data with the one computed on Google server,
it will over time get better at being GMail. Once there, slowly moving to
external accounts becomes easier. After a while, it become possible to pull the
plug on GMail.

### Bonus points

This project also aims at making scripting easy so you can pre-process your
mails with tools.

## Components

### OfflineIMAP

This component synchronize an IMAP (GMail) server with a local maildir. It uses
Google OAuth2 autentification and docker secrets to store your tokens. Your
password is never required and access can be revoked from the GMail setting if
the device is ever compromised.

### A Xapian/Notmuch frontend

This component index and tag your emails. It imports the filter and labels from
GMail itself and tries to replicate the indexing and filtering locally.

It is internally a pipeline of 3 different notmuch frontends:

 * "notmuch new" iself add files to he database
 * process.lua Apply the GMail filters and call the pre-processing scripts
 * frontend.lua Display an ncuses TUI with the status information and stats

### VCard and aBook

This component extracts metadata from the mails and import the contacts from
your Google account.

### A NeoMutt distribution

NeoMutt is a downstream from the venerable Mutt mail user agent. This is
downstream of NeoMutt with some extra extensions and a more modern theme. The
main difference compared to raw NeoMutt is that it uses Lua scripts intead of
configuration files.

