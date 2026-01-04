local chat = start_require "multiplayer/server/chat/chat"
local states = start_require "multiplayer/server/chat/chat_states"
local account_manager = start_require "server:lib/private/accounts/account_manager"
local module = {}

module.colors = {
    red =    "[#ff0000]",
    yellow = "[#ffff00]",
    blue =   "[#0000FF]",
    black =  "[#000000]",
    green =  "[#00FF00]",
    white =  "[#FFFFFF]",
    gray =   "[#4d4d4d]"
}

local function __parse_scheme(scheme)
    local main_part, rest = scheme:match("^([^:]+):(.+)$")
    if not main_part then
        error("Ошибка: строка должна содержать ':' для разделения")
    end

    local args_part, action = rest:match("^(.+)%->%s*(.+)$")
    if not args_part then
        error("Ошибка: строка должна содержать '->' для разделения")
    end

    local args = {}
    for arg in args_part:gmatch("[^,%s]+") do
        table.insert(args, arg)
    end

    local optional_found = false
    for _, arg in ipairs(args) do
        local _, _, _, close_bracket = arg:match("^([^=]+)=([%[<])([^%]>]+)([%]>])$")
        if not close_bracket then
            error("Ошибка: аргумент в неверном формате: " .. arg)
        end
        if close_bracket == "]" then
            optional_found = true
        elseif close_bracket == ">" and optional_found then
            error("Ошибка: обязательный аргумент не может следовать за необязательным: " .. arg)
        end
    end

    local result = {main_part}
    for _, arg in ipairs(args) do
        table.insert(result, arg)
    end
    table.insert(result, action)

    return result
end

local function __parse_arg(arg)

    local key, bracket_open, value, bracket_close = arg:match("^([^=]+)=([%[<])([^%]>]+)([%]>])$")
    if not key or not bracket_open or not value or not bracket_close then
        error("Ошибка: строка должна быть в формате 'key=<value>' или 'key=[value]'")
    end

    local bracketType = (bracket_open == "<" and bracket_close == ">") and "!" or "~"

    return {key, value, bracketType}
end

local function __parse_arg_name(arg)
    local key, value = arg:match("^(.-)=(.*)$")
    if arg[1] == '"' or arg[1] == "'" then
        key = nil
    end

    if key == nil then
        key = ""
        value = arg
    end
    return {key, value}
end

function module.create_state(name)
    return states.create_state(name)
end

function module.tell(message, client)
    chat.tell(message, client)
end

function module.echo(message)
    chat.echo(message)
end

function module.set_state(state, client)
    state:__set(client)
end

function module.set_state_handler(state, handler)
    return chat.set_state_handler(state, handler)
end

function module.set_command(command, permissions, handler, is_no_logged)
    local scheme = __parse_scheme(command)
    local args_definitions = table.sub(scheme, 2, #scheme - 1)
    args_definitions = table.map(args_definitions, function(_, val)
        return __parse_arg(val)
    end)

    local function check_type(arg_type, value)
        if arg_type[2] == "any" then return true end
        if arg_type[3] == "!" and string.type(value) ~= arg_type[2] then return false end
        if arg_type[3] == "~" and string.type(value) ~= arg_type[2] then return false end
        return true
    end

    return chat.add_command(scheme, function(args, client)
        local unnamed_args = {}
        local named_args = {}

        for _, arg in ipairs(args) do
            local parsed = __parse_arg_name(arg)
            if parsed[1] == "" then
                table.insert(unnamed_args, parsed[2])
            else
                named_args[parsed[1]] = parsed[2]
            end
        end

        local parsed_args = {}
        local unnamed_index = 1

        for _, arg_def in ipairs(args_definitions) do
            local key, expected_type, requirement = unpack(arg_def)

            local value = named_args[key]

            if value == nil and unnamed_index <= #unnamed_args then
                value = unnamed_args[unnamed_index]
                unnamed_index = unnamed_index + 1
            end

            if requirement == "!" and value == nil then
                chat.tell(string.format("%s Missing required argument: %s", module.colors.red, key), client)
                return
            end

            if value ~= nil and not check_type(arg_def, value) then
                chat.tell(string.format("%s Invalid type for argument: %s", module.colors.red, key), client)
                return
            end

            if type(value) == "string" then
                value = string.trim_quotes(value)
            end

            local _, cast = string.type(value)
            parsed_args[key] = cast(value)
        end

        for scope, perms in pairs(permissions) do
            local rules = account_manager.get_rules(client.account, scope == "server")
            for _, perm in ipairs(perms) do
                if not rules[perm] then
                    chat.tell(string.format("%s You do not have sufficient permissions to perform this action!", module.colors.red), client)
                    return
                end
            end
        end

        handler(parsed_args, client)
    end, is_no_logged)
end


function module.execute(command, client)
    chat.command(command, client)
end

module.set_command("help: command=[string] -> Shows a list of available commands.", {}, function (args, client)
    local command = args.command
    local handlers = chat.get_handlers()
    local message = string.format("\n%s----- Help (/help) -----\n", module.colors.yellow)

    local function concat(schem)
        local main_part = schem[1]

        local action = schem[#schem]

        local _args = {}
        for i = 2, #schem - 1 do
            table.insert(_args, schem[i])
        end

        local args_part = table.concat(_args, ", ")

        local scheme = main_part .. ": " .. args_part .. " -> " .. action
        return scheme
    end

    if not command then
        for _, com in pairs(handlers) do
            local schem = concat(com.schem)
            message = message .. module.colors.yellow .. schem .. '\n'
        end
    else
        command = handlers[command]
        if not command then
            module.tell(string.format("%s %s", module.colors.red, "Unknow command"), client)
            return
        end

        command = command.schem

        local tbl_message = {
            module.colors.yellow .. "Command name: " .. command[1],
            module.colors.yellow .. "Description: " .. command[#command],
            module.colors.yellow .. "Args:"
        }

        for i=2, #command-1 do
            local arg = command[i]
            local parse_arg = __parse_arg(arg)
            table.insert(tbl_message, string.format(
                "%s[%s]    %s=%s",
                module.colors.yellow,
                parse_arg[3],
                parse_arg[1],
                parse_arg[2]
            ))
        end

        if #tbl_message == 3 then
            table.insert(tbl_message, module.colors.yellow .. "    No args")
        end

        message = message .. table.concat(tbl_message, "\n")
    end

    module.tell(string.format("%s %s", module.colors.yellow, message), client)
end)

return module