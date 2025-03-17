local chat = start_require "multiplayer/server/chat/chat"
local account_manager = start_require "server:lib/private/accounts/account_manager"
local module = {}

module.colors = {
    red = "[#ff0000]",
    yellow = "[#ffff00]",
    blue = "[#0000FF]",
    black = "[#000000]",
    green = "[#00FF00]",
    white = "[#FFFFFF]"
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

function module.tell(message, client)
    chat.tell(message, client)
end

function module.echo(message)
    chat.echo(message)
end

function module.set_command(command, permitions, handler)
    local scheme = __parse_scheme(command)
    local args_types = table.sub(scheme, 2, #scheme-1)
    args_types = table.map(args_types, function (_, val) return __parse_arg(val) end)

    local function check(arg_type, arg)
        if arg_type[2] ~= "any" then
            if arg_type[3] == '!' then
                return string.type(arg) ~= arg_type[2]
            elseif arg_type[3] == '~' then
                return string.type(arg) ~= arg_type[2] and arg
            end
        end
    end

    return chat.add_command(scheme, function (args, client)
        local parsed_args = {}
        local unnamed_args = {}
        local named_args = {}

        for _, arg in ipairs(args) do
            local parsed_arg = __parse_arg_name(arg)
            if parsed_arg[1] == "" then
                table.insert(unnamed_args, parsed_arg[2])
            else
                named_args[parsed_arg[1]] = parsed_arg[2]
            end
        end

        for i, arg_value in ipairs(unnamed_args) do
            local arg_type = args_types[i]
            if arg_type then
                parsed_args[arg_type[1]] = arg_value
            end
        end

        for key, value in pairs(named_args) do
            parsed_args[key] = value
        end

        local required_args_count = 0
        local temp_args = {}

        for _, arg_type in ipairs(args_types) do
            local key = arg_type[1]
            local value = parsed_args[key]

            if value == nil and arg_type[3] == '!' then
                chat.tell(string.format("%s %s", module.colors.red, "Missing required argument: " .. key), client)
                return
            end

            if value ~= nil and check(arg_type, value) then
                chat.tell(string.format("%s %s", module.colors.red, "Invalid argument type for: " .. key), client)
                return
            end

            if arg_type[3] == '!' then
                required_args_count = required_args_count + 1
            end

            local _type, typefunc = string.type(value)
            if _type == "string" then
                value = string.trim_quotes(value)
            end
            temp_args[key] = typefunc(value)
        end

        for _, permition in ipairs(permitions) do
            local rules = account_manager.get_rules(client.account, true)

            if not rules[permition] then
                chat.tell(string.format("%s %s", module.colors.red, "You do not have sufficient permissions to perform this action!"), client)
                return
            end
        end

        handler(temp_args, client)
    end)
end

function module.execute(command, client)
    chat.command(command, client)
end

module.set_command("help: command=[string] -> Shows a list of available commands.", {}, function (args, client)
    local command = args.command
    local handlers = chat.get_handlers()
    local message = string.format("\n%s----- Help (.help) -----\n", module.colors.yellow)

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