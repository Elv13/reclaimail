--- Main NeoMutt configuration file rewritten in Lua

local unpack = unpack or table.unpack --lua 5.1 compat
local sections    = require( "sections"    )
local keybindings = require( "keybindings" )
local option      = require( "options"     )
local theme       = require( "theme"       )
local notmuch = option.add_namespace { "nm" }

------------------------------------
--       Generic settings         --
------------------------------------

-- Variables
local maildir = os.getenv("HOME").."/Mail"

-- Sending mails
option.sendmail    = "/usr/bin/msmtp"

-- Maildir settings
option.mbox_type   = "Maildir"
option.folder      = "~/Mail/"
option.spoolfile   = "+INBOX"
option.mbox        = "+[Gmail]/All Mail"
option.postponed   = "+[Gmail]/Drafts"

-- Pager View Options
option.date_format       = "%b %d %Y, %I:%M"
option.pager_index_lines = 10   -- number of index lines to show
option.pager_context     = 3    -- number of context lines to show
option.pager_stop        = true -- don't go to next message automatically
option.menu_scroll       = true -- scroll in menus
option.tilde             = true -- show tildes like in vim
mutt.command.unset("markers")   -- no ugly plus signs

option.virtual_spoolfile = true

-- Sorting
option.sort         = "threads"
--option.sort_browser = "reverse-date"
option.sort_aux     = "reverse-last-date-received"

mutt.push = "<last-entry>"

------------------------------------
--             Sidebar            --
------------------------------------

local sidebar = option.add_namespace { "sidebar" }

--TODO port to Lua
sidebar.format = "%B%* %?N?%N/?%S"

sidebar.visible = true
sidebar.width = 24
sidebar.divider_char = "⢸"

------------------------------------
--             Colors             --
------------------------------------

-- Generic
theme.normal     = theme.color { fg = "white"}
theme.attachment = theme.color { fg = "brightyellow"}
theme.hdrdefault = theme.color { bg = "color233"}
theme.indicator  = theme.color { fg = "black", bg = "cyan"}
theme.markers    = theme.color { fg = "brightred"}
theme.quoted     = theme.color { fg = "green"}
theme.signature  = theme.color { fg = "cyan"}
theme.status     = theme.color { bg = "color232"}
theme.tilde      = theme.color { fg = "blue"}
theme.tree       = theme.color { fg = "red"}

-- Quotes
theme.quoted  = theme.color {bg = "color232" }
theme.quoted1 = theme.color {bg = "color233" }
theme.quoted2 = theme.color {bg = "color234" }
theme.quoted3 = theme.color {bg = "color235" }

-- Index background color
theme.index = {
    theme.color { bg = "color52" , when = "~N"},
    theme.color { bg = "color52" , when = "~U"},
    theme.color { fg = "red"     , when = "~P"},
    theme.color { fg = "red"     , when = "~D"},
    theme.color { fg = "magenta" , when = "~T"}
}

------------------------------------
--      Virtual mailboxes         --
------------------------------------

-- Notmuch
notmuch.default_uri="notmuch://"..maildir..""
--notmuch.default_uri="notmuch://?query=tag:Awesome"

-- Define all the email tag to be used for the sidebar and the index
local tags = {
    {name = "inbox"       , display_tag = false,                               },
    {name = "sent"        , display_tag = true                                 },
    {name = "archive"     , display_tag = false,                               },
    {name = "Mutt"        , display_tag = true ,                               },
    {name = "newsletters" , display_tag = true ,                               },
    {name = "KDE"         , display_tag = true , bg = "color20" , fg="color255"},
    {name = "GitHub"      , display_tag = true , bg = "color248", fg = "color0"},
    {name = "Awesome"     , display_tag = true , bg = "color34" , fg = "color0"},
    {name = "Voicemail"   , display_tag = true , bg = "color34" , fg = "color0"},
}

--TODO create an helper for this
option.index_format = " %-30.30F│ %s %> " .. theme.generate_tags(tags) .. "│%D"

------------------------------------
--           Key bindings         --
------------------------------------

-- Notmuch virtual folder navigation
keybindings.add {
    keybindings.macro {{"index"}, {}, "/", "<vfolder-from-query>", "Indexed search"},
    keybindings.macro {{"index"}, {}, "t", "<vfolder-from-query>tag:", "Select tag"},
}

------------------------------------
--           Status bar           --
------------------------------------

-- The bar displayed when the email index is displayed
local status_bar = {
    left_separator  = "⮀",
    right_separator = "⮂",
    left = {
        {
            label = "Folder",
            section = sections.status.mailbox.path,
            bg = "color124",
        },
        {
            label = "Total",
            section = sections.status.mails.count,
            bg = "color78",
            fg = "color0",

        },
        {
            label = "Unread",
            section = sections.status.mails.unread,
            bg = "color93",
        }
    },
    center = {
        fill = " "
    },
    right = {
        {
            label = "hello",
            section = sections.status.mails.percent,
            bg = "color93",
        }
    },
}

-- The bar displayed when an email is being viewed
local info_bar = {
    left_separator  = "⮀",
    right_separator = "⮂",
    left = {
        {
            label = "Box",
            bg = "color124",
            fg = "color0",
            section = sections.index.line_count
        },
        {
            label = "From",
            bg = "color78",
            fg = "color0",
            section = sections.index.author_address
        },
        {
            label = "Date",
            section = sections.index.local_time,
            bg = "color93",
        }
    },
    center = {
        fill = " "
    },
    right = {
        label = " of ",
        bg = "color78",
        fg = "color0",
        section = sections.index.line_count
    },
}

theme.status = theme.color {
    bg = "white", fg = "red", when = '"[a-z]:[A-Z][a-z]"'
}

option.status_format = theme.gen_powerline(status_bar)
option.pager_format  = theme.gen_powerline(info_bar)
