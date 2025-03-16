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

    chat.add_command(scheme, function (args, client)
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

            local _, typefunc = string.type(value)
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

return module