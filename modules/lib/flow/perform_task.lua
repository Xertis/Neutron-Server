local module = {}

local funcs = {}

function module.perform(func)
    funcs[#funcs + 1] = func
end

function module.process()
    local funcs_ptr = funcs
    funcs = {}
    for i = 1, #funcs_ptr do
        funcs_ptr[i]()
    end
end

return module
