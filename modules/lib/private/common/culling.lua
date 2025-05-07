local protect = require "lib/private/protect"
local sandbox = require "lib/private/sandbox/sandbox"

local module = {}

function module.in_radius(center, radius, dot)
    return ((center.x - dot.x)^2 + (center.y - dot.y)^2)^0.5 <= radius
end

return protect.protect_return(module)