local object = require("patchbay.object")

local module = {}

local active, historical, reported = {}, {}, {}

local state_change

local function archive(self)
    for k, v in ipairs(active) do
        if v == self then
            table.remove(active, k)
            table.insert(historical, self)
            self:disconnect_signal("property::state", state_change)
            return
        end
    end
end

local function updated(self)
     module.emit_signal("outage::updated", self)
end

state_change = function(self, current_state, previous_state)
    if self.state == "FAILURE" or self.state == "RECOVERED" then
        archive(self)
        module.emit_signal("outage::end", self)
    elseif self.state == "ONGOING" and not reported[self] then
        module.emit_signal("outage::begin", self)
        reported[self] = true
    end
end

function module._register_incident(inc)
    assert(inc.state)

    if inc.state == "FAILURE" or inc.state == "RECOVERED" then
        table.insert(historical, inc)
    else
        inc:connect_signal("property::state", state_change)
        inc:connect_signal("updated", updated)
        table.insert(active, inc)

        state_change(inc, inc.state, nil)
    end
end

object.patch_table(module, {
    is_module       = true,
    load_submodules = "patchbay.outage",
})

return module
