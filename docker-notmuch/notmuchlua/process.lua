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

filters.path = "mailFilters.xml"

local labels = filters.path and filters.tags or {}

-- use: `echo BYE | nc -w0 -Uu ~/query.socket` to quit

server.listen(function(command)
    tui.set_remote_state(command:sub(1, command:len()-1))
    os.execute("bash -c 'notmuch new'") -- > /dev/null 2> /dev/null'")

    -- There is nothing to do
    if command:sub(1, 3) ~= "NEW" then return end

    tui.set_local_state("SCANNING")

    local db = notmuch "/home/notmuch/GMail/"
    assert(db)

    local q = "tag:new"

    local new_messages = db:get_messages(q)

    tui.set_local_state("LOADING ("..#new_messages..")")
    for _, m in ipairs(new_messages) do
        local ret, error = pcall(tui.print_message, m.path)

        if not ret then
             print("FAILED TO PARSE", m.path, ret)
        end

        m:remove_tag("new")
    end

    if filters.path then
        for _, query in ipairs(filters.queries) do
            tui.set_local_state("QUERY "..query.query)
            local messages = db:get_messages(query.query)

            for _, m in ipairs(messages) do
                for _, new_tag in diff_tags_iterator(m.tags, query.tags) do
                    m:add_tag(new_tag)
                end
            end
        end
    end

    db:close()

    tui.set_local_state("IDLE")
end)
