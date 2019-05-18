local function is_directory(path)
   local f = io.open(path)

   if not f then return false end

   local ok, err, code = f:read(1)

   f:close()

   return code == 21
end

local gen_procmt = nil

-- Create a recursive table for the subdirectories
gen_procmt = function(path, prefix)
    local real = {}
    return setmetatable(real, {
        __index = function(_, key)
           local newpath = prefix..path.."/"..key.."/"
           if not is_directory(newpath) then
               local f = io.open(prefix..path.."/"..key)
               assert(f, "Trying to read or write to an invalid path "..newpath)

               local ret = f:read("*all*")
               f:close()

               return ret
           else
               rawset(real, key, gen_procmt(path.."/"..key, prefix))
               return real[key]
           end       
       end,
       __newindex = function(_, key, value)
           local f = io.open(prefix..path.."/"..key, "w")

           if not f then
               print("Could not write to "..prefix..path.."/"..key..
                     " Either dnsmasq is not running as root or this"..
                     " container isn't privileged")
               --assert(false)
           else
               f:write(value)
               f:close()
           end
       end
    })
end

-- Avoid luafilesystem for now.
local function get_interfaces()
    local f, ret = io.popen("ls /sys/class/net"), {}
    local ints = f:read("*all*")

    for i in ints:gmatch("([^ \n]+)") do
        ret[i] = gen_procmt(i, "/sys/class/net/")
    end

    return ret
end

local ip =  {
    v4 = gen_procmt("v4", "/proc/sys/net/ip"), 
    v6 = gen_procmt("v6", "/proc/sys/net/ip")
}

local interfaces = get_interfaces()

assert(ip and interfaces)

return {ip, interfaces}
