local protect = require "lib/private/protect"
if protect.protect_require() then return end

local module = {}
local DATA = {}

function module.put(key, val, indx)
    table.set_default(DATA, key, {})
    indx = indx or #DATA[key]+1

    DATA[key][indx] = val
end

function module.get_all(key)
    return table.set_default(DATA, key, {})
end

return module