local notmuch = require( "notmuch" )
local server  = require( "server"  )
local filters = require( "filters" )
local tui     = require( "tui"     )

local function pretty_print_tags(tags)
    local ret = ""
    for t in pairs(tags) do
        ret = ret .. " ["..t.."]"
    end

    return ret
end

--- Generate a list of tags to add to the mail
local function diff_tags_iterator(existing, new)
    local ret = {}

    for t in pairs(new) do
        if not existing[t] then
            table.insert(ret, t)
        end
    end

    return ipairs(ret)
end

filters.path = "/home/lepagee/Downloads/mailFilters.xml"

local labels = filters.tags

-- use: `echo BYE | nc -w0 -Uu ~/query.socket` to quit

server.listen(function(command)
    tui.set_remote_state(command:sub(1, command:len()-1))
    tui.set_local_state("SCANNING")
    os.execute("bash -c 'notmuch new > /dev/null 2> /dev/null'")

    -- There is nothing to do
    if command ~= "NEW\n" then return end

    local db = notmuch "/home/lepagee/Mail/"
    assert(db)

    local q = "tag:new"

    local new_messages = db:get_messages(q)

    tui.set_local_state("LOADING ("..#new_messages..")")
    for _, m in ipairs(new_messages) do
        tui.print_message(m.path)
        m:remove_tag("new")
    end

    for _, query in ipairs(filters.queries) do
        tui.set_local_state("QUERY "..query.query)
        local messages = db:get_messages(query.query)

        for _, m in ipairs(messages) do
            for _, new_tag in diff_tags_iterator(m.tags, query.tags) do
                m:add_tag(new_tag)
            end
        end
    end
    db:close()

    tui.set_local_state("IDLE")
end)

