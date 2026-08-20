local module = {}

local funcs = {}

function module.perform(func)
    funcs[#funcs + 1] = func
end

function module.process()
    local funcs_ptr = funcs
    funcs = {}
    for i = 1, #funcs_ptr do
        local ok, err = pcall(funcs_ptr[i])
        if not ok then
            logger.log("Error in deferred task func: " .. err, "E")
        end
    end
end

return module
