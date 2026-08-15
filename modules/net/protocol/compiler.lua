local types_parser = import "net/protocol/types_parser"
local tokenizer = import "net/protocol/tokenizer"

local bincode = import "lib/io/bincode"
local bson = import "lib/data/bson"
local edd = import "lib/data/edd"
local http = import "lib/http/httprequestparser"

local module = {}

local PARSED_INFO = types_parser.get_info()

local FUNCTION_PATTERN_ENCODER = [[
return function (buf, data)
%s
end
]]

local FUNCTION_PATTERN_DECODER = [[
return function (buf)
    local result = {}
%s
%s
    return result
end
]]

local function replace_substr(str, replacement, start_pos, end_pos)
    return str:sub(1, start_pos - 1) .. replacement .. str:sub(end_pos + 1)
end

local function split_top_level(str)
    local parts        = {}
    local depth_angle  = 0
    local depth_square = 0
    local depth_curly  = 0
    local current      = ""

    for i = 1, #str do
        local c = str:sub(i, i)
        if c == "<" then
            depth_angle = depth_angle + 1
        elseif c == ">" then
            depth_angle = depth_angle - 1
        elseif c == "[" then
            depth_square = depth_square + 1
        elseif c == "]" then
            depth_square = depth_square - 1
        elseif c == "{" then
            depth_curly = depth_curly + 1
        elseif c == "}" then
            depth_curly = depth_curly - 1
        elseif c == "," and depth_angle == 0 and depth_square == 0 and depth_curly == 0 then
            table.insert(parts, current:match("^%s*(.-)%s*$"))
            current = ""
            goto continue
        end
        current = current .. c
        ::continue::
    end

    if #current > 0 then
        table.insert(parts, current:match("^%s*(.-)%s*$"))
    end
    return parts
end

local function is_valid_ident(s)
    return type(s) == "string" and s:match("^[%a_][%w_]*$") ~= nil
end

local function accessor(base, name)
    if is_valid_ident(name) then
        return base .. "." .. name
    end
    return base .. "[" .. string.format("%q", name) .. "]"
end

local function split_path(name)
    local parts = {}
    for part in name:gmatch("[^%.]+") do
        table.insert(parts, part)
    end
    return parts
end

local function sorted_keys(tbl)
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys)
    return keys
end

local function find_foreign_call(code)
    local pattern = "Foreign(%d*)%s*%(%s*([^)]*)%s*%)"
    local start_pos, end_pos, num_str, arg = code:find(pattern)
    if start_pos then
        arg = arg and arg:match("^%s*(.-)%s*$") or ""
        local index = 1
        if num_str ~= "" then
            index = tonumber(num_str)
            if index == 0 then index = 1 end
        end
        return { start = start_pos, finish = end_pos, res_token = arg, index = index }
    end
    return nil
end

local function pop_last_bracket(str)
    local s = str:match("^(.-)%s*$")
    if s:sub(-1) ~= "]" then return nil, str end

    local depth = 0
    for i = #s, 1, -1 do
        local c = s:sub(i, i)
        if c == "]" then
            depth = depth + 1
        elseif c == "[" then
            depth = depth - 1
            if depth == 0 then
                local content   = s:sub(i + 1, #s - 1)
                local remaining = s:sub(1, i - 1)
                return content, remaining
            end
        end
    end
    return nil, str
end

local function parse_type(str)
    local w_expr, r_expr = nil, nil
    local base_str = str

    while true do
        local content, remaining = pop_last_bracket(base_str)
        if not content then break end

        content = content:match("^%s*(.-)%s*$")
        if content:find("W") then
            w_expr = content
        elseif content:find("R") then
            r_expr = content
        end

        base_str = remaining
    end

    local outer, inner_str = base_str:match("^%s*([^<>]+)%s*<%s*(.*)%s*>%s*$")
    if outer then
        local parts = split_top_level(inner_str)
        local inners = {}
        for _, part in ipairs(parts) do
            table.insert(inners, parse_type(part))
        end
        return {
            type_name = outer:match("^%s*(.-)%s*$"),
            inners    = inners,
            w_expr    = w_expr,
            r_expr    = r_expr,
        }
    else
        return {
            type_name = base_str:match("^%s*(.-)%s*$"),
            inners    = nil,
            w_expr    = w_expr,
            r_expr    = r_expr,
        }
    end
end

local function compile_encode_type(type_node, cur_index, override_save_token)
    local type_name = type_node.type_name
    local info = PARSED_INFO.encode[type_name]
    local to_save = info.TO_SAVE
    local vars = info.VARIABLES or {}
    local sum_vars_to_gen = override_save_token and vars or table.merge({ to_save }, vars)

    local tokens = {}
    tokens, cur_index = tokenizer.get_tokens(cur_index, sum_vars_to_gen)

    if override_save_token then
        tokens[to_save] = override_save_token
    end

    local code = tokenizer.variables_replace(info.code, tokens)
    local save_token = tokens[to_save]

    if type_node.w_expr then
        local expr = tokenizer.variables_replace(type_node.w_expr, { W = save_token })
        code = string.format("    %s = %s\n%s", save_token, expr, code)
    end

    if type_node.inners then
        local replaced = true
        while replaced do
            replaced = false
            local foreign = find_foreign_call(code)
            if foreign then
                replaced = true
                local inner = type_node.inners[foreign.index]
                if not inner then
                    error(string.format(
                        "Foreign%d: тип '%s' имеет только %d inner-типов",
                        foreign.index, type_name, #type_node.inners
                    ))
                end
                local res_token = foreign.res_token ~= "" and foreign.res_token or nil
                local inner_code, _, new_cur_index = compile_encode_type(inner, cur_index, res_token)
                code = replace_substr(code, inner_code, foreign.start, foreign.finish)
                cur_index = new_cur_index
            end
        end
    end

    return code, save_token, cur_index
end

local function compile_decode_type(type_node, cur_index, override_load_token)
    local type_name = type_node.type_name
    local info = PARSED_INFO.decode[type_name]
    local to_load = info.TO_LOAD
    local vars = info.VARIABLES or {}
    local sum_vars_to_gen = override_load_token and vars or table.merge({ to_load }, vars)

    local tokens = {}
    tokens, cur_index = tokenizer.get_tokens(cur_index, sum_vars_to_gen)

    if override_load_token then
        tokens[to_load] = override_load_token
    end

    local code = tokenizer.variables_replace(info.code, tokens)
    local load_token = tokens[to_load]

    if type_node.inners then
        local replaced = true
        while replaced do
            replaced = false
            local foreign = find_foreign_call(code)
            if foreign then
                replaced = true
                local inner = type_node.inners[foreign.index]
                if not inner then
                    error(string.format(
                        "Foreign%d: тип '%s' имеет только %d inner-типов",
                        foreign.index, type_name, #type_node.inners
                    ))
                end
                local res_token = foreign.res_token ~= "" and foreign.res_token or nil
                local inner_code, _, new_cur_index = compile_decode_type(inner, cur_index, res_token)
                code = replace_substr(code, inner_code, foreign.start, foreign.finish)
                cur_index = new_cur_index
            end
        end
    end

    if type_node.r_expr then
        local expr = tokenizer.variables_replace(type_node.r_expr, { R = load_token })
        code = code .. string.format("\n    %s = %s", load_token, expr)
    end

    return code, load_token, cur_index
end

function module.compile_encoder(fields)
    local keys = sorted_keys(fields)

    if #keys == 0 then
        return "return function (buf, data) end"
    end

    local concated_code = ""
    local cur_index = 0

    for _, name in ipairs(keys) do
        local type_node = parse_type(fields[name])
        local code, to_save, cur_indx = compile_encode_type(type_node, cur_index, nil)
        cur_index = cur_indx

        local parts = split_path(name)
        local access = "data"
        for i, part in ipairs(parts) do
            access = accessor(access, part)
            if i < #parts then
                access = "(" .. access .. " or {})"
            end
        end

        concated_code = string.format("%s    local %s = %s\n%s ", concated_code, to_save, access, code)
    end

    return string.format(FUNCTION_PATTERN_ENCODER, concated_code)
end

function module.compile_decoder(fields)
    local keys = sorted_keys(fields)

    if #keys == 0 then
        return "return function (buf) return {} end"
    end

    local read_code = ""
    local assign_code = ""
    local cur_index = 0
    local ensured = {}

    for _, name in ipairs(keys) do
        local type_node = parse_type(fields[name])
        local code, to_load, cur_indx = compile_decode_type(type_node, cur_index, nil)
        cur_index = cur_indx

        read_code = string.format("%s%s ", read_code, code)

        local parts = split_path(name)
        local access = "result"
        for i = 1, #parts - 1 do
            access = accessor(access, parts[i])
            if not ensured[access] then
                ensured[access] = true
                assign_code = string.format("%s    %s = %s or {}\n", assign_code, access, access)
            end
        end
        access = accessor(access, parts[#parts])
        assign_code = string.format("%s    %s = %s\n", assign_code, access, to_load)
    end

    return string.format(FUNCTION_PATTERN_DECODER, read_code, assign_code)
end

function module.load(code)
    local env = {
        math = math,
        table = table,
        string = string,
        unpack = unpack,
        type = type,
        bit = bit,
        Bytearray = Bytearray,
        compression = compression,
        http = http,
        utf8 = utf8,
        bson = bson,
        bincode = bincode,
        edd = edd,

        MAX_UINT16 = 65535,
        MIN_UINT16 = 0,
        MAX_UINT32 = 4294967295,
        MIN_UINT32 = 0,
        MAX_UINT64 = 18446744073709551615,
        MIN_UINT64 = 0,

        MAX_BYTE = 255,
        MIN_BYTE = 0,

        MAX_INT8 = 127,
        MAX_INT16 = 32767,
        MAX_INT32 = 2147483647,
        MAX_INT64 = 9223372036854775807,

        MIN_INT8 = -127,
        MIN_INT16 = -32768,
        MIN_INT32 = -2147483648,
        MIN_INT64 = -9223372036854775808
    }

    local keys = {}
    local values = {}

    for key in pairs(env) do
        table.insert(keys, key)
        table.insert(values, "e." .. key)
    end

    local header = string.format("local e = ...; local %s = %s;\n",
        table.concat(keys, ", "),
        table.concat(values, ", "))

    local final_code = header .. code

    local loader, err = load(final_code)
    if not loader then
        error("Ошибка компиляции байт-кода: " .. tostring(err))
    end

    return loader(env)
end

return module
