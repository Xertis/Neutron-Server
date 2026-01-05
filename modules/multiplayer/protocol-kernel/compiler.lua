local types_parser = require "multiplayer/protocol-kernel/types_parser"
local tokenizer = require "multiplayer/protocol-kernel/tokenizer"

local bincode = require "server:lib/public/common/bincode"
local bson = require "server:lib/private/files/bson"
local edd = require "server:lib/private/files/edd"
local http = require "server:lib/private/http/httprequestparser"

local module = {}

local PARSED_INFO = types_parser.get_info()

local FUNCTION_PATTERN_ENCODER = [[
return function (buf, %s) 
%s
end
]]

local FUNCTION_PATTERN_DECODER = [[
return function (buf) 
%s
    return {%s}
end
]]

local function replace_substr(str, replacement, start_pos, end_pos)
    return str:sub(1, start_pos - 1) .. replacement .. str:sub(end_pos + 1)
end

local function find_foreign_call(code)
    local pattern = "Foreign%s*%(%s*([^)]*)%s*%)"

    local start_pos, end_pos, arg = code:find(pattern)

    if start_pos then
        arg = arg and arg:match("^%s*(.-)%s*$") or ""

        return {
            start = start_pos,
            finish = end_pos,
            res_token = arg
        }
    else
        return nil
    end
end

local function parse_type_tree(str)
    local outer, inner_str = str:match("^([^<>]+)<(.*)>$")
    if not outer then
        return {type_name = str, inner = nil}
    end
    return {type_name = outer, inner = parse_type_tree(inner_str)}
end

local function compile_encode_type(type_node, cur_index, override_save_token)
    local type_name = type_node.type_name
    local info = PARSED_INFO.encode[type_name]
    local to_save = info.TO_SAVE
    local vars = info.VARIABLES
    local sum_vars_to_gen = override_save_token and vars or table.merge({to_save}, vars)

    local tokens = {}
    tokens, cur_index = tokenizer.get_tokens(cur_index, sum_vars_to_gen)

    if override_save_token then
        tokens[to_save] = override_save_token
    end

    local code = tokenizer.variables_replace(info.code, tokens)
    local save_token = tokens[to_save]

    if type_node.inner then
        local replaced = true
        while replaced do
            replaced = false
            local foreign = find_foreign_call(code)
            if foreign then
                replaced = true
                local res_token = foreign.res_token
                local inner_code, _, new_cur_index = compile_encode_type(type_node.inner, cur_index, res_token)
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
    local vars = info.VARIABLES
    local sum_vars_to_gen = override_load_token and vars or table.merge({to_load}, vars)

    local tokens = {}
    tokens, cur_index = tokenizer.get_tokens(cur_index, sum_vars_to_gen)

    if override_load_token then
        tokens[to_load] = override_load_token
    end

    local code = tokenizer.variables_replace(info.code, tokens)
    local load_token = tokens[to_load]

    if type_node.inner then
        local replaced = true
        while replaced do
            replaced = false
            local foreign = find_foreign_call(code)
            if foreign then
                replaced = true
                local res_token = foreign.res_token
                local inner_code, _, new_cur_index = compile_decode_type(type_node.inner, cur_index, res_token)
                code = replace_substr(code, inner_code, foreign.start, foreign.finish)
                cur_index = new_cur_index
            end
        end
    end

    return code, load_token, cur_index
end

function module.compile_encoder(types)
    local concated_code = ""
    local cur_index = 0
    local sum_tokens = {}

    if #types == 0 then
        return "return function () end"
    end

    for _, typestr in ipairs(types) do
        local type_node = parse_type_tree(typestr)
        local code, to_save, cur_indx = compile_encode_type(type_node, cur_index, nil)
        cur_index = cur_indx
        table.insert(sum_tokens, to_save)

        concated_code = string.format("%s%s ", concated_code, code)
    end

    local args = table.concat(sum_tokens, ', ')
    return string.format(FUNCTION_PATTERN_ENCODER, args, concated_code)
end

function module.compile_decoder(types)
    local concated_code = ""
    local cur_index = 0
    local sum_tokens = {}

    if #types == 0 then
        return "return function () end"
    end

    for _, typestr in ipairs(types) do
        local type_node = parse_type_tree(typestr)
        local code, to_load, cur_indx = compile_decode_type(type_node, cur_index, nil)
        cur_index = cur_indx
        table.insert(sum_tokens, to_load)

        concated_code = string.format("%s%s ", concated_code, code)
    end

    local returns = table.concat(sum_tokens, ', ')
    return string.format(FUNCTION_PATTERN_DECODER, concated_code, returns)
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

    local func = load(code)()
    setfenv(func, env)
    return func
end

return module