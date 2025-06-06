local types_parser = require "server:multiplayer/protocol-kernel/types_parser"
local tokenizer = require "server:multiplayer/protocol-kernel/tokenizer"

local bincode = require "server:lib/public/common/bincode"
local bson = require "server:lib/private/files/bson"

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
    return %s
end
]]

function module.compile_encoder(types)
    local concated_code = ""
    local cur_index = 0
    local sum_tokens = {}
    for _, type in ipairs(types) do
        local type_info = PARSED_INFO.encode[type]

        local to_save = type_info.TO_SAVE
        local vars = type_info.VARIABLES
        local code = type_info.code
        local sum_vars = table.merge({to_save}, vars)

        local tokens = nil
        tokens, cur_index = tokenizer.get_tokens(cur_index, sum_vars)

        for var, token in pairs(tokens) do
            if var == to_save then
                table.insert(sum_tokens, token)
                break
            end
        end

        code = tokenizer.variables_replace(code, tokens)
        concated_code = string.format("%s%s ", concated_code, code)
    end

    local args = table.concat(sum_tokens, ', ')
    return string.format(FUNCTION_PATTERN_ENCODER, args, concated_code)
end

function module.compile_decoder(types)
    local concated_code = ""
    local cur_index = 0
    local sum_tokens = {}
    for _, type in ipairs(types) do
        local type_info = PARSED_INFO.decode[type]

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
    end

    local returns = table.concat(sum_tokens, ', ')
    return string.format(FUNCTION_PATTERN_DECODER, concated_code, returns)
end

function module.load(code)
    local env = {
        bson = bson,
        bincode = bincode,
        math = math
    }

    local func = load(code)()
    setfenv(func, env)
    return func
end

return module