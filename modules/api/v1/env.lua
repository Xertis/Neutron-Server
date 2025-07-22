local server_echo = start_require("multiplayer/server/server_echo")
local protocol = require "multiplayer/protocol-kernel/protocol"

local envs = {}
local module = {
    public = {},
    private = {}
}

-- Если меняется значение, кидаем на другую сторону новое значение
-- Если значение не меняется, возвращаем значение из своей таблички

function module.public.create(pack, env_name)
    local data = {}
    local proxy = {}

    local pack_envs = table.set_default(envs, pack, {})
    pack_envs[env_name] = data

    setmetatable(proxy, {
        __metatable = false,

        __index = function(_, key)
            return data[key]
        end,

        __newindex = function(_, key, value)
            if not table.has({"number", "boolean", "string", "nil"}, type(value)) then
                error("Env-table cannot contain " .. type(value) .. "'s")
            elseif type(key) ~= "string" then
                error("Env-table can only contain key-value pairs")
            end

            data[key] = value

            server_echo.put_event(
                function (client)
                    if client.active ~= true then
                        return
                    end

                    client:push_packet(protocol.ServerMsg.PackEnv, pack, env_name, key, value)
                end
            )
        end,
    })

    return proxy
end

function module.private.create(pack, env_name, client)
    local data = {}
    local proxy = {}

    local pack_envs = table.set_default(envs, pack, {})
    pack_envs[env_name] = data

    setmetatable(proxy, {
        __metatable = false,

        __index = function(_, key)
            return data[key]
        end,

        __newindex = function(_, key, value)
            if not table.has({"number", "boolean", "string", "nil"}, type(value)) then
                error("Env-table cannot contain " .. type(value) .. "'s")
            elseif type(key) ~= "string" then
                error("Env-table can only contain key-value pairs")
            end

            data[key] = value

            if client.active ~= true then
                return
            end

            client:push_packet(protocol.ServerMsg.PackEnv, pack, env_name, key, value)
        end,
    })

    return proxy
end

function module.__env_update__(pack, env_name, key, value)
    local pack_envs = envs[pack] or {}

    if pack_envs[env_name] == nil then
        logger.log(string.format('The env-table "%s" of the "%s" pack was not created, but a value for it was obtained.', env_name, pack), 'E')
        return
    end

    pack_envs[env_name][key] = value

    server_echo.put_event(
        function (client)
            if client.active ~= true then
                return
            end

            client:push_packet(protocol.ServerMsg.PackEnv, pack, env_name, key, value)
        end
    )
end

return module