local module = {}

local LOG_ACCESS_DENIES = "Unauthorized Access attempt from "
local ACCESS_DENIES = "Access denied"

local function parse_path(path)
    if table.has({
        "main.lua",
        "tests.lua", "script:main.lua", "script:tests.lua",
        "[string]",  "=[C]",
    }, path) then
        return "server", ""
    end

    local index = string.find(path, ':')
    if index == nil then
        error("invalid path syntax (':' missing)")
    end
    return string.sub(path, 1, index-1), string.sub(path, index+1, -1)
end

local function get_traceback_length()
    local traceback = debug.traceback()
    local count = 0

    for _ in traceback:gmatch("[^\n]+") do
        count = count + 1
    end

    return count-2
end

local function freeze(original)
    local copy = {}
    setmetatable(copy, {
        __index = original,
        __metatable = false,
        __newindex = function(t, key, value)
            logger.log("Unauthorized Access attempt to the system meta-table", "W")
        end,
    })

    return copy
end

function module.protect_return(val)
    for call=1, get_traceback_length() do
        local source = debug.getinfo(call).source
        local prefix, path = parse_path(source)
        if prefix == "server" and path:find("api") then
            break
        end

        if prefix ~= "server" and prefix ~= "core" then
            logger.log(LOG_ACCESS_DENIES .. source, "W")
            return ACCESS_DENIES
        end
    end

    return val
end

function module.protect_require()
    for call=1, get_traceback_length() do
        local source = debug.getinfo(call).source

        local prefix, path = parse_path(source)
        if prefix == "server" and path:find("api") then
            break
        end

        if prefix ~= "server" and prefix ~= "core" then
            logger.log(LOG_ACCESS_DENIES .. source, "W")
            return ACCESS_DENIES
        end
    end
end

return freeze(module)