local protect = require "lib/private/protect"
local protocol = require "multiplayer/protocol-kernel/protocol"
local server_echo = require "multiplayer/server/server_echo"
local states = require "multiplayer/server/chat/chat_states"
local sandbox = require "lib/private/sandbox/sandbox"
local account_manager = require "lib/private/accounts/account_manager"
local module = {}

local no_logged_commands = {}
local handlers = {}

function module.echo(message)
    logger.log(message)

    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.ChatMessage, {message}))

    server_echo.put_event(function(client)
        client:queue_response(buffer.bytes)
    end)
end

function module.echo_with_mentions(message)
    logger.log(message)

    local color = "[#CE9C5C]"
    local mentions, mention_message = module.mention_prepare(message)

    local exclients = {}
    for _, name in ipairs(mentions) do
        if name == "everyone" then
            module.echo(color .. message)
            return
        end

        local exclient = account_manager.by_username.get_client(name)
        if exclient then
            table.insert(exclients, exclient)
        end
    end

    local buffer = protocol.create_databuffer()
    buffer:put_packet(protocol.build_packet("server", protocol.ServerMsg.ChatMessage, {mention_message}))

    server_echo.put_event(function(client)
        client:queue_response(buffer.bytes)
    end, unpack(exclients))

    for _, client in ipairs(exclients) do
        module.tell(color .. message, client)
    end
end

function module.mention_prepare(message)
    local mentions = {}

    local words = {}
    for word in message:gmatch("%S+") do
        table.insert(words, word)
    end

    for i, word in ipairs(words) do
        if string.starts_with(word, '@') then
            local name = string.sub(word, 2)
            if name == "everyone" then
                return { "everyone" }, message
            end

            while not sandbox.by_username.is_online(name) and #name > 0 do
                name = string.drop_last(name)
            end

            if sandbox.by_username.is_online(name) then
                table.insert(mentions, name)
                words[i] = "[#5865F2]" .. word .. "[#FFFFFF]"
            end
        end
    end

    return mentions, table.concat(words, ' ')
end

function module.tell(message, client)
    client:push_packet(protocol.ServerMsg.ChatMessage, {message})
end

function module.command(message, client)
    local state = states.get_state(client)

    if message[1] ~= COMMAND_PREFIX and not state then
        return false
    end

    if not state then
        message = string.sub(message, 2)
    end

    local args = string.soft_space_split(message)
    local executable = args[1]
    table.remove(args, 1)

    if not client.account.is_logged and not table.has(no_logged_commands, executable) then
        return
    end

    if handlers[executable] and not state then
        handlers[executable].handler(args, client)
    elseif state then
        handlers[state.id].handler(message, state, client)
    else
        module.tell("[#ff0000] Unknow command: " .. executable, client)
    end
end

function module.add_command(schem, handler, is_no_logged)
    if handlers[schem[1]] then
        return false
    end

    if is_no_logged then
        table.insert(no_logged_commands, schem[1])
    end

    handlers[schem[1]] = { handler = handler, schem = schem }
    return true
end

function module.set_state_handler(state, handler)
    if handlers[state.id] then
        return false
    end

    handlers[state.id] = { handler = handler }
end

function module.get_handlers()
    local pairs_handlers = {}

    for key, handler in pairs(handlers) do
        if type(key) ~= "number" then
            pairs_handlers[key] = handler
        end
    end
    return pairs_handlers
end

return protect.protect_return(module)
