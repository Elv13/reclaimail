local notmuch = require("notmuch")
local server  = require("server" )
local filters = require("filters")

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
    os.execute("notmuch new")

    local db = notmuch "/home/lepagee/Mail/"
    assert(db)

    local q = "tag:new"

    local new_messages = db:get_messages(q)
    print("M", #new_messages)

    for _, m in ipairs(new_messages) do
        print("GOT NEW", m.path)
        m:remove_tag("new")
    end

    for _, query in ipairs(filters.queries) do
        print("QUERY", command, query)
        local messages = db:get_messages(query.query)

        for _, m in ipairs(messages) do
            for _, new_tag in diff_tags_iterator(m.tags, query.tags) do
                print("FOUND NEW", new_tag, query.query, m.path, pretty_print_tags(m.tags))
                m:add_tag(new_tag)
            end
        end
    end
    db:close()
    print("IDLE")
end)

