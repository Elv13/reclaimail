
local sections = {}

--FIXME remove this hack
local delimiter = "⮀"

-- Try to make the statusbar DLS Lua friendly
sections.status = {
    version  = {"%v", "[0-9]+"}, --NeoMutt version string
    hostname = {"%h", "[0-9]+"}, --Local hostname
    mailbox  = {
        count_new   = {"%b", "[0-9]+"}, --Number of mailboxes with new mail *
        size        = {"%l", "[0-9]+"}, --Size (in bytes) of the current mailbox *
        description = {"%D", "[0-9]+"}, --Description of the mailbox
        path        = {"%f", "[^"..delimiter.."]+"}, --The full pathname of the current mailbox
    },
    mail = {
        size = {"%L", "[0-9]+"}, --Size (in bytes) of the messages shown (i.e., which match the current limit) *
    },
    mails = {
        deleted    = {"%d", "[0-9]+"}, --Number of deleted messages *
        flagged    = {"%F", "[0-9]+"}, --Number of flagged messages *
        count      = {"%m", "[0-9]+"}, --The number of messages in the mailbox *
        shown      = {"%M", "[0-9]+"}, --The number of messages shown (i.e., which match the current limit) *
        new        = {"%n", "[0-9]+"}, --Number of new messages in the mailbox *
        old_unread = {"%o", "[0-9]+"}, --Number of old unread messages *
        postponed  = {"%p", "[0-9]+"}, --Number of postponed messages *
        percent    = {"%P", "[0-9]+"}, --Percentage of the way through the index
        read       = {"%R", "[0-9]+"}, --Number of read messages *
        tagged     = {"%t", "[0-9]+"}, --Number of tagged messages *
        unread     = {"%u", "[0-9]+"}, --Number of unread messages *
    },
    sorting = {
        mode   = {"%s", "[0-9]+"}, --Current sorting mode ( $sort)
        method = {"%S", "[0-9]+"}, --Current aux sorting method ( $sort_aux)
    },
   -- = "%r" --Modified/read-only/won't-write/attach-message indicator, According to $status_chars
   -- = "%V" --Currently active limit pattern, if any *
}
-- "%>X" --Right justify the rest of the string and pad with “X”
-- "%|X" --Pad to the end of the line with “X”
-- "%*X" --Soft-fill with character “X” as pad

sections.index = {
    author_address = {"%a", "[^ ]+"}, --Address of the author
    reply_address  = {"%A", "[^ ]+"}, --Reply-to address (if present; otherwise: address of author)
    filename       = {"%b", "[0-9]+"}, --Filename of the original message folder (think mailbox)
    mailing_list   = {"%B", "[0-9]+"}, --The list to which the letter was sent, or else the folder name (%b).
    mailbox_number = {"%C", "[0-9]+"}, --Current message number
    size           = {"%c", "[0-9]+"}, --Number of characters (bytes) in the message
    local_time     = {"%D", "[^"..delimiter.."]+"}, --Date and time of message using date_format and local timezone
    sender_timer   = {"%d", "[0-9]+"}, --Date and time of message using date_format and sender's timezone
    thread_number  = {"%e", "[0-9]+"}, --Current message number in thread
    thread_count   = {"%E", "[0-9]+"}, --Number of messages in current thread
    author_name    = {"%F", "[0-9]+"}, --Author name, or recipient name if the message is from you
    line_count     = {"%l", "[0-9]+"}, --Number of lines in the message (does not work with maildir, Mh, and possibly IMAP folders)
    foo = "%Fp", --Like %F, but plain. No contextual formatting is applied to recipient name
    foo = "%f", --Sender (address + real name), either From: or Return-Path:
    foo = "%g", --Newsgroup name (if compiled with NNTP support)
    foo = "%g", --Message tags (e.g. notmuch tags/imap flags)
    foo = "%Gx", --Individual message tag (e.g. notmuch tags/imap flags)
    foo = "%H", --Spam attribute(s) of this message
    foo = "%I", --Initials of author
    foo = "%i", --Message-id of the current message
    foo = "%J", --Message tags (if present, tree unfolded, and != parent's tags)
    foo = "%K", --The list to which the letter was sent (if any; otherwise: empty)
    foo = "%L", --If an address in the “To:” or “Cc:” header field matches an address Defined by the users “ subscribe ” command, this displays "To <list-name>", otherwise the same as %F
    foo = "%M", --Number of hidden messages if the thread is collapsed
    foo = "%m", --Total number of message in the mailbox
    foo = "%N", --Message score
    foo = "%n", --Author's real name (or address if missing)
    foo = "%O", --Original save folder where NeoMutt would formerly have Stashed the message: list name or recipient name If not sent to a list
    foo = "%P", --Progress indicator for the built-in pager (how much of the file has been displayed)
    foo = "%q", --Newsgroup name (if compiled with NNTP support)
    foo = "%R", --Comma separated list of “Cc:” recipients
    foo = "%r", --Comma separated list of “To:” recipients
    foo = "%S", --Single character status of the message ( “N”/ “O”/ “D”/ “d”/ “!”/ “r”/ “*”)
    foo = "%s", --Subject of the message
    foo = "%T", --The appropriate character from the $to_chars string
    foo = "%t", --“To:” field (recipients)
    foo = "%u", --User (login) name of the author
    foo = "%v", --First name of the author, or the recipient if the message is from you
    foo = "%W", --Name of organization of author ( “Organization:” field)
    foo = "%x", --“X-Comment-To:” field (if present and compiled with NNTP support)
    foo = "%X", --Number of MIME attachments (please see the “ attachments ” section for possible speed effects)
    foo = "%Y", --“X-Label:” field, if present, and (1) not at part of a thread tree, (2) at the top of a thread, or (3) “X-Label:” is different from Preceding message's “X-Label:”
    foo = "%y", --“X-Label:” field, if present
    foo = "%Z", --A three character set of message status flags. The first character is new/read/replied flags ( “n”/ “o”/ “r”/ “O”/ “N”). The second is deleted or encryption flags ( “D”/ “d”/ “S”/ “P”/ “s”/ “K”). The third is either tagged/flagged ( “*”/ “!”), or one of the characters Listed in $to_chars.
    foo = "%zc", --Message crypto flags
    foo = "%zs", --Message status flags
    foo = "%zt", --Message tag flags
    foo = "%{fmt}", --the date and time of the message is converted to sender's time zone, and “fmt” is expanded by the library function strftime(3); a leading bang disables locales
    foo = "%[fmt]", --the date and time of the message is converted to the local time zone, and “fmt” is expanded by the library function strftime(3); a leading bang disables locales
    foo = "%(fmt)", --the local date and time when the message was received. “fmt” is expanded by the library function strftime(3); a leading bang disables locales
    foo = "%>X", --right justify the rest of the string and pad with character “X”
    foo = "%|X", --pad to the end of the line with character “X”
    foo = "%*X", --soft-fill with character “X” as pad
}

return sections
