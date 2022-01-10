local module = {}

function module.filename(path)
    return path:match('[^/]+$')
end

--- Convert mac / hwaddr addresses from string to 2 byte seuqence.
function module.hwaddr_to_sequ(addr)
    return {
        addr,
        addr:sub(1, 14),
        addr:sub(1, 11),
        addr:sub(1, 8),
        addr:sub(1, 5),
        addr:sub(1, 2)
    }
end

--- Convert a netmask (ie, 255.255.255.0 to /24)
function module.netmask_to_cidr(netmask)
    local i = 3

    -- The algorithm is rather simple, get the modulo until `1` is
    -- found. Go from right to left.
    for component in string.reverse(netmask):gmatch("([0-9]+)[.]*") do
        local num = tonumber(string.reverse(component))

        -- Invalid mask.
        if num < 0 or num > 255 then return 0 end

        for j = 0, 7 do
            -- As soon as the first `1` bit is found, quit.
            if num % 2 == 1 then
                return (8-j) + (i*8)
            end

            -- No need to substract rest, it can only be 0.
            num = math.ceil(num/2)
        end

        i = i - 1
    end

    return 0
end

return module
