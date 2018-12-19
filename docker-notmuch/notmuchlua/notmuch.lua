--- This is a LuaJIT FFI binding for the notmuch mail indexer.
--
-- It only supports LuaJIT2 and nothing else.
--
-- The first version only support running queries and tagging the result. That's
-- about has much (ah ah) as notmuch does anyway.
--
-- The thread support seems to crash, no thread tagging for now.
--
local ffi = require("ffi")
local io = io

local cnotmuch = ffi.load("notmuch")

-- local c_head = io.open("/usr/include/notmuch.h"):read("*all")

local c_head = [[
    typedef struct _notmuch_database notmuch_database_t;
    typedef struct {} notmuch_query_t;
    typedef struct {} notmuch_messages_t;
    typedef struct {} notmuch_message_t;
    typedef struct {} notmuch_threads_t;
    typedef struct {} notmuch_thread_t;
    typedef struct {} notmuch_tags_t;
    typedef int notmuch_bool_t;
    typedef int notmuch_status_t;
    typedef int notmuch_database_mode_t;

    notmuch_status_t
    notmuch_database_open (const char *path,
                notmuch_database_mode_t mode,
                notmuch_database_t **database);

    notmuch_query_t *
    notmuch_query_create (notmuch_database_t *database,
                const char *query_string);

    notmuch_status_t
        notmuch_query_search_messages_st (notmuch_query_t *query,
                        notmuch_messages_t **out);

    notmuch_bool_t
    notmuch_messages_valid (notmuch_messages_t *messages);

    void
    notmuch_messages_move_to_next (notmuch_messages_t *messages);

    notmuch_message_t *
    notmuch_messages_get (notmuch_messages_t *messages);

    const char *
    notmuch_message_get_filename (notmuch_message_t *message);

    const char *
    notmuch_message_get_thread_id (notmuch_message_t *message);

    notmuch_messages_t *
    notmuch_message_get_replies (notmuch_message_t *message);

    const char *
    notmuch_message_get_message_id (notmuch_message_t *message);

    notmuch_status_t
    notmuch_database_close (notmuch_database_t *database);

    notmuch_status_t
    notmuch_query_search_threads_st (notmuch_query_t *query,
                    notmuch_threads_t **out);

    notmuch_bool_t
    notmuch_threads_valid (notmuch_threads_t *threads);

    void
    notmuch_threads_move_to_next (notmuch_threads_t *threads);

    notmuch_thread_t *
    notmuch_threads_get (notmuch_threads_t *threads);

    void
    notmuch_query_destroy (notmuch_query_t *query);

    void
    notmuch_messages_destroy (notmuch_messages_t *messages);

    notmuch_tags_t *
    notmuch_message_get_tags (notmuch_message_t *message);

    void
    notmuch_tags_move_to_next (notmuch_tags_t *tags);

    notmuch_bool_t
    notmuch_tags_valid (notmuch_tags_t *tags);

    const char *
    notmuch_tags_get (notmuch_tags_t *tags);

    void
    notmuch_tags_destroy (notmuch_tags_t *tags);

    notmuch_status_t
    notmuch_message_add_tag (notmuch_message_t *message, const char *tag);

    notmuch_status_t
    notmuch_message_remove_tag (notmuch_message_t *message, const char *tag);

    notmuch_status_t
    notmuch_message_remove_all_tags (notmuch_message_t *message);
]]

ffi.cdef(c_head)

local get_messages = nil

local function open_db(path)
    local db = ffi.new("notmuch_database_t*[1]")
    local err = cnotmuch.notmuch_database_open(path, 1, db)
    assert(err == 0, "Error: "..tonumber(err))

    return {
        _db = db[0],
        get_messages = function(_, query) return get_messages(db[0], query) end,
        close = function() cnotmuch.notmuch_database_close(db[0]) end
    }
end

local thread_obj = {}

local function get_thread(db, thread_id)
    local query = cnotmuch.notmuch_query_create(db, "thread:"..thread_id)
    local threads = ffi.new("notmuch_threads_t*[1]")

    --FIXME segfault
    local err = cnotmuch.notmuch_query_search_threads_st(query, threads)
    assert(err == 0, "Error: "..tonumber(err))
    assert(cnotmuch.notmuch_threads_valid(threads[0]) == 1)

    local thread = setmetatable({
        _thread = cnotmuch.notmuch_threads_get(threads[0])}, {
        __index = function(self, key)
            if thread_obj["get_"..key] then
                return thread_obj["get_"..key](self)
            end
        end
    })

    cnotmuch.notmuch_query_destroy(query)

    return thread
end

local mess_obj = {}

function mess_obj:get_id()
    self.id = cnotmuch.notmuch_message_get_message_id(self._message)
    return self.id
end

function mess_obj:get_path()
    self.path = ffi.string(cnotmuch.notmuch_message_get_filename(self._message))
    return self.path
end

function mess_obj:get_thread()
    self.thread = get_thread(
        self._thread, ffi.string(cnotmuch.notmuch_message_get_thread_id(self._message))
    )
    return self.thread
end

function mess_obj:get_tags()
    local tags = cnotmuch.notmuch_message_get_tags(self._message)
    self.tags = {}

    while cnotmuch.notmuch_tags_valid(tags) == 1 do
        self.tags[ffi.string(cnotmuch.notmuch_tags_get(tags))] = true
        cnotmuch.notmuch_tags_move_to_next(tags)
    end

    cnotmuch.notmuch_tags_destroy(tags)

    return self.tags
end

function mess_obj:add_tag(name)
    cnotmuch.notmuch_message_add_tag(self._message, name)
    self.tags = nil
end

function mess_obj:remove_tag(name)
    cnotmuch.notmuch_message_remove_tag(self._message, name)
    self.tags = nil
end

function mess_obj:remove_all_tags()
    cnotmuch.notmuch_message_remove_all_tags(self._message)
    self.tags = nil
end

get_messages = function (db, q)
    local ret = {}
    local query = cnotmuch.notmuch_query_create(db, q)
    local messages = ffi.new("notmuch_messages_t*[1]")
    local err = cnotmuch.notmuch_query_search_messages_st(query, messages)
    assert(err == 0, "Error: "..tonumber(err))

    while cnotmuch.notmuch_messages_valid(messages[0]) == 1 do
        local message = setmetatable({
                _message = cnotmuch.notmuch_messages_get(messages[0]),
                _db = db
            }, {
            __index = function(self, key)
                if mess_obj["get_"..key] then
                    return mess_obj["get_"..key](self)
                elseif mess_obj[key] then
                    return mess_obj[key]
                end
            end
        })

        table.insert(ret, message)

        cnotmuch.notmuch_messages_move_to_next(messages[0])
    end

--     cnotmuch.notmuch_messages_destroy(messages[0])
--     cnotmuch.notmuch_query_destroy(query)

    return ret
end

return open_db
