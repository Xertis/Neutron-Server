local types_parser = require "server:multiplayer/protocol-kernel/types_parser"
local tokenizer = require "server:multiplayer/protocol-kernel/tokenizer"

local bincode = require "server:lib/public/common/bincode"
local bson = require "server:lib/private/files/bson"
local edd = require "server:lib/private/files/edd"

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

local function find_foreign_call(code)
    local pattern = "Foreign[%w_]*%s*%(%s*([^,)]+)%s*,?%s*([^)]*)%s*%)"

    local start_pos, end_pos, arg1, arg2 = code:find(pattern)

    if start_pos then
        arg1 = arg1 and arg1:match("^%s*(.-)%s*$") or ""
        arg2 = arg2 and arg2:match("^%s*(.-)%s*$") or ""

        return {
            start = start_pos,
            finish = end_pos,
            type_token = arg1,
            res_token = arg2
        }
    else
        return nil
    end
end

local function parse_type(str)
    local outer_type, inner_type = str:match("^([^<>]+)<([^<>]+)>$")

    if outer_type and inner_type then
        return outer_type, inner_type
    else
        return str
    end
end

local function loop_encode(cur_index, outer, inner)
    local outer_info, inner_info = PARSED_INFO.encode[outer], PARSED_INFO.encode[inner]
    local outer_code = outer_info.code
    local inner_code = inner_info.code
    local sum_vars_outer = table.merge({outer_info.TO_SAVE, outer_info.TO_LOOPED}, outer_info.VARIABLES)

    local tokens_outer = nil
    tokens_outer, cur_index = tokenizer.get_tokens(cur_index, sum_vars_outer)

    outer_code = tokenizer.variables_replace(outer_code, tokens_outer)
    local foreign = find_foreign_call(outer_code)
    local result_token = foreign.res_token

    local inner_to_save = inner_info.TO_SAVE
    local sum_vars_inner = table.merge({inner.TO_SAVE}, inner_info.VARIABLES or {})

    local tokens_inner = nil
    tokens_inner, cur_index = tokenizer.get_tokens(cur_index, sum_vars_inner)
    tokens_inner[inner_to_save] = result_token

    inner_code = tokenizer.variables_replace(inner_code, tokens_inner)
    outer_code = string.replace_substr(outer_code, inner_code, foreign.start, foreign.finish)

    return outer_code, tokens_outer[outer_info.TO_SAVE], cur_index
end

local function loop_decode(cur_index, outer, inner)
    local outer_info, inner_info = PARSED_INFO.decode[outer], PARSED_INFO.decode[inner]
    local outer_code = outer_info.code
    local inner_code = inner_info.code
    local sum_vars_outer = table.merge({outer_info.TO_LOAD, outer_info.TO_LOOPED}, outer_info.VARIABLES)

    local tokens_outer = nil
    tokens_outer, cur_index = tokenizer.get_tokens(cur_index, sum_vars_outer)

    outer_code = tokenizer.variables_replace(outer_code, tokens_outer)
    local foreign = find_foreign_call(outer_code)
    local result_token = foreign.res_token

    local inner_to_load = inner_info.TO_LOAD
    local sum_vars_inner = table.merge({inner.TO_LOAD}, inner_info.VARIABLES or {})

    local tokens_inner = nil
    tokens_inner, cur_index = tokenizer.get_tokens(cur_index, sum_vars_inner)
    tokens_inner[inner_to_load] = result_token

    inner_code = tokenizer.variables_replace(inner_code, tokens_inner)
    outer_code = string.replace_substr(outer_code, inner_code, foreign.start, foreign.finish)

    return outer_code, tokens_outer[outer_info.TO_LOAD], cur_index
end

function module.compile_encoder(types)
    local concated_code = ""
    local cur_index = 0
    local sum_tokens = {}

    if #types == 0 then
        return "return function () end"
    end

    for _, type in ipairs(types) do
        local outer, inner = parse_type(type)
        local type_info = PARSED_INFO.encode[outer]

        if inner then
            local code, to_save, cur_indx = loop_encode(cur_index, outer, inner)
            cur_index = cur_indx
            table.insert(sum_tokens, to_save)

            concated_code = string.format("%s%s ", concated_code, code)
            goto continue
        end

        local code = type_info.code
        local to_save = type_info.TO_SAVE

        local vars = type_info.VARIABLES
        local sum_vars = table.merge({to_save}, vars)

        local tokens = nil
        tokens, cur_index = tokenizer.get_tokens(cur_index, sum_vars)

        table.insert(sum_tokens, tokens[to_save])

        code = tokenizer.variables_replace(code, tokens)
        concated_code = string.format("%s%s ", concated_code, code)
        ::continue::
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

    for _, type in ipairs(types) do
        local outer, inner = parse_type(type)
        local type_info = PARSED_INFO.decode[outer]

        if inner then
            local code, to_load, cur_indx = loop_decode(cur_index, outer, inner)
            cur_index = cur_indx
            table.insert(sum_tokens, to_load)

            concated_code = string.format("%s%s ", concated_code, code)
            goto continue
        end

        local to_load = type_info.TO_LOAD
        local vars = type_info.VARIABLES
        local code = type_info.code
        local sum_vars = table.merge({to_load}, vars)

        local tokens = nil
        tokens, cur_index = tokenizer.get_tokens(cur_index, sum_vars)

        for var, token in pairs(tokens) do
            if var == to_load then
                table.insert(sum_tokens, token)
                break
            end
        end

        code = tokenizer.variables_replace(code, tokens)
        concated_code = string.format("%s%s ", concated_code, code)
        ::continue::
    end

    local returns = table.concat(sum_tokens, ', ')
    return string.format(FUNCTION_PATTERN_DECODER, concated_code, returns)
end

function module.load(code)
    local env = {
        bson = bson,
        bincode = bincode,
        math = math,
        table = table,
        string = string,
        unpack = unpack,
        type = type,
        bit = bit,
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