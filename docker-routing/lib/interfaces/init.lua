local base = require("reclaim.routing.interfaces._base")

local function wan(args)
    args.area = "wide"
    args.role = "wan"
    return base(args)
end

local function lan(args)
    args.area = "local"
    return base(args)
end

return {
   wireguard = require("reclaim.routing.interfaces.wireguard"),
   wan       = wan,
   lan       = lan,
}
