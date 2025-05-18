function start_require(path)
    if not string.find(path, ':') then
        local prefix, _ = parse_path(debug.getinfo(2).source)
        return start_require(prefix..':'..path)
    end

    local prefix, file = parse_path(path)
    path = prefix..":modules/"..file..".lua"

    if not _G["/$p"] then
        return
    end

    return _G["/$p"][path]
end

local server_echo = start_require("server:multiplayer/server/server_echo")
local protocol = start_require("server:lib/public/protocol")
local sandbox = start_require("server:lib/private/sandbox/sandbox")

local function upd(blockid, x, y, z, playerid)
    local data = {
        x,
        y,
        z,
        block.get_states(x, y, z),
        block.get(x, y, z),
        playerid
    }

    server_echo.put_event(
        function (client)
            if client.active ~= true then
                return
            end

            local client_states = sandbox.get_player_state(client.player)

            if math.euclidian2D(
                client_states.x,
                client_states.z,
                x,
                z
            ) > (CONFIG.server.chunks_loading_distance+5) then
                return
            end

            local buffer = protocol.create_databuffer()
            buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.BlockChanged, unpack(data)))
            client.network:send(buffer.bytes)
        end
    )
end


function on_block_placed( ... )
    upd(...)
end

function on_block_broken( ... )
    upd(...)
end

events.on("server:block_interact", function (...)
    upd(...)
end)

function on_world_open()
    local api = require "server:api/api".server
    local _entities = api.entities

    _entities.register(
        "base:falling_block",
        {
            custom_fields = {},
            standart_fields = {
                tsf_pos = {
                    maximum_deviation = 1,
                    evaluate_deviation = function (dist, cur_val, client_val)
                        if not client_val then
                            return 3
                        end
                        return math.euclidian3D(
                            cur_val[1], cur_val[2], cur_val[3],
                            client_val[1], client_val[2], client_val[3]
                        )
                    end},
                tsf_rot = {
                    maximum_deviation = 1,
                    evaluate_deviation = function (dist, cur_val, client_val)
                        return 0
                    end
                },
                tsf_size = {
                    maximum_deviation = 1,
                    evaluate_deviation = function (dist, cur_val, client_val)
                        return 0
                    end},
                body_size = {
                    maximum_deviation = 1,
                    evaluate_deviation = function (dist, cur_val, client_val)
                        return 0
                    end},
            },
            textures = {
                ['$0'] = {
                    maximum_deviation = 1,
                    evaluate_deviation = function (dist, cur_val, client_val)
                        return cur_val ~= client_val and 2 or 0
                    end},
                ['$1'] = {
                    maximum_deviation = 1,
                    evaluate_deviation = function (dist, cur_val, client_val)
                        return cur_val ~= client_val and 2 or 0
                    end},
                ['$2'] = {
                    maximum_deviation = 1,
                    evaluate_deviation = function (dist, cur_val, client_val)
                        return cur_val ~= client_val and 2 or 0
                    end},
                ['$3'] = {
                    maximum_deviation = 1,
                    evaluate_deviation = function (dist, cur_val, client_val)
                        return cur_val ~= client_val and 2 or 0
                    end},
                ['$4'] = {
                    maximum_deviation = 1,
                    evaluate_deviation = function (dist, cur_val, client_val)
                        return cur_val ~= client_val and 2 or 0
                    end},
                ['$5'] = {
                    maximum_deviation = 1,
                    evaluate_deviation = function (dist, cur_val, client_val)
                        return cur_val ~= client_val and 2 or 0
                    end},
            },
            components = {
                ["base:falling_block"] = {
                    maximum_deviation = 1,
                    evaluate_deviation = function (dist, cur_val, client_val)
                        return client_val ~= false and 2 or 0
                    end,
                    provider = function ()
                        return false
                    end
                }
            }
        }
    )

_entities.register(
        "base:drop",
        {
            custom_fields = {},
            standart_fields = {
                tsf_pos = {
                    maximum_deviation = 0.1,
                    evaluate_deviation = function (dist, cur_val, client_val)
                        if not client_val then
                            return 3
                        end
                        return math.euclidian3D(
                            cur_val[1], cur_val[2], cur_val[3],
                            client_val[1], client_val[2], client_val[3]
                        )
                    end},
                tsf_rot = {
                    maximum_deviation = 1,
                    evaluate_deviation = function (dist, cur_val, client_val)
                        return 0
                    end
                },
                tsf_size = {
                    maximum_deviation = 1,
                    evaluate_deviation = function (dist, cur_val, client_val)
                        return 0
                    end},
                body_size = {
                    maximum_deviation = 1,
                    evaluate_deviation = function (dist, cur_val, client_val)
                        return 0
                    end},
            },
            models = {
                ["0"] = {
                    maximum_deviation = 1,
                    evaluate_deviation = function (dist, cur_val, client_val)
                        return cur_val ~= client_val and 2 or 0
                    end},
            },
            components = {
                ["base:drop"] = {
                    maximum_deviation = 1,
                    evaluate_deviation = function (dist, cur_val, client_val)
                        return client_val ~= false and 2 or 0
                    end,
                    provider = function ()
                        return false
                    end
                }
            }
        }, function (name, args, client)
            local tbl = table.merge({name}, args)
            entities.spawn(unpack(tbl))
        end
    )
end