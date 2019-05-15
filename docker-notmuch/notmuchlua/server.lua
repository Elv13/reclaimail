-- Stolen from https://github.com/trisulnsm/trisul-scripts/
-- License unspecified
-- Itself apparently stolen from https://stackoverflow.com/questions/6025755

local ffi = require('ffi')

local EVE_SOCKETFILE = os.getenv("HOME")..'/GMail/query.socket'

-- need to do this mapping .. :-(
-- takes time to get used to LuaJIT FFI but quite easy once you get the
-- hang of it
ffi.cdef[[
typedef int      ssize_t;
typedef uint16_t sa_family_t;
typedef uint32_t socklen_t;

struct constants {
    static const int AF_UNIX=1;
    static const int AF_INET=2;
    static const int SOCK_DGRAM=2;          /* socket.h        */
    static const int MSG_DONTWAIT=0x40;     /* socket_type.h   */
    static const int EAGAIN=11;     /* asm../errno.h */
};

int socket(int domain, int type, int protocol);

struct sockaddr {
    sa_family_t sa_family;
    char        sa_data[14];
};

struct sockaddr_un {
    sa_family_t   sun_family;
    uint8_t  sun_path[108];
};

int bind(int socket, const struct sockaddr *, socklen_t addrlen) ;
ssize_t recv(int socket, void * buf, size_t buflen, int flags);
size_t strlen(const char * s);
char * strerror(int errno);
int unlink(char * pathname);
]]


function strerror()
  return ffi.string(ffi.C.strerror( ffi.errno() ))
end

local K = ffi.new("struct constants")

local active_socket = nil

local function onload()

    print("Suricata EVE Unix Socket script - setting up the socket : ".. EVE_SOCKETFILE)

    -- socket
    local socket = ffi.C.socket( K.AF_UNIX, K.SOCK_DGRAM, 0 )
    if socket == -1 then
      print("Error socket() " .. strerror())
      return
    end

    -- bind to unix socket endpoint
    local addr = ffi.new("struct sockaddr_un");
    addr.sun_family = K.AF_UNIX;
    addr.sun_path = EVE_SOCKETFILE
    ffi.C.unlink(addr.sun_path);
    local ret = ffi.C.bind( socket,  ffi.cast("const struct sockaddr *", addr) , ffi.sizeof(addr));


    print ("Ret = "..ret.." pah="..ffi.string(addr.sun_path) )
    if ret == -1 then
        print("Error bind() " .. strerror())
        return false
    end

    active_socket = socket

end

local function step_alert(callback, blocking, timeout)
    local MAX_MSG_SIZE=2048;
    local rbuf = ffi.new("char[?]", MAX_MSG_SIZE);

    -- this block is repeated
    -- 1. until an 'alert' JSON is found (suricata sends other types of info too via EVE))
    -- 2. EOF on socket
    local p = nil
    repeat
        local ret = ffi.C.recv(active_socket, rbuf,MAX_MSG_SIZE,blocking and K.MSG_DONTWAIT or 0)
        if ret < 0 then
            if ffi.errno()  == K.EAGAIN then
                print("Nothing to read" )
                return nil
            else
                print("Error ffi.recv " .. strerror())
                return nil
            end
        end

        if ret >= MAX_MSG_SIZE then
            print("Ignoring large JSON, probably not an alert len="..ret);
            return nil
        end

        local command = ffi.string(rbuf, ret)

        callback(command)
    until command == "BYE\n"

    return ret;
end

local function epoch_secs( suri_rfc3339)
    local year , month , day , hour , min , sec , tv_usec, patt_end =
                suri_rfc3339:match ( "^(%d%d%d%d)%-(%d%d)%-(%d%d)[Tt](%d%d%.?%d*):(%d%d):(%d%d).(%d+)+()" );

    local tv_sec  = os.time( { year = year, month = month, day = day, hour = hour, min = min, sec = sec});

    return tv_sec,tv_usec

end

function protocol_num(protoname)
    if protoname == "TCP" then return 6
    elseif protoname == "UDP" then return 17
    elseif protoname == "ICMP" then return 1
    else return 0; end
end

local module = {}

function module.listen(callback, blocking, timeout)
    onload()
    step_alert(callback, blocking, timeout)
end

return module
