local PATH_TO_PARSER = "server:default_data/protocol/parsers.lua"
local module = {}

function module.parse_content(content)
    local ENCODE = {}
    local DECODE = {}

    local read_start_pos = content:find("--@READ_START")
    if not read_start_pos then
        return ENCODE, DECODE
    end

    local remaining_content = content:sub(read_start_pos + #"--@READ_START")

    local block_pattern = "%-%-%s*@([%w_]+)%.([%w]+)([%s%S]-)do([%s%S]-)end"

    for block_type, operation, header, code in remaining_content:gmatch(block_pattern) do
        local variables = {}
        local vars_part = header:match("VARIABLES%s+([^\n]*)")
        if vars_part then
            vars_part = vars_part:gsub("%-%-.*", ""):gsub("%s+$", "")
            for var in vars_part:gmatch("%S+") do
                table.insert(variables, var)
            end
        end

        local to_action, to_var = header:match("TO_([%w_]+)%s+([%w_]+)")

        if operation == "write" then
            ENCODE[block_type] = {
                VARIABLES = variables,
                TO_SAVE = to_var or "",
                code = code
            }
        elseif operation == "read" then
            DECODE[block_type] = {
                VARIABLES = variables,
                TO_LOAD = to_var or "",
                code = code
            }
        end
    end

    return ENCODE, DECODE
end

local file_content = file.read(PATH_TO_PARSER)
local encode, decode = module.parse_content(file_content)
local parsed_info = {
    encode = encode,
    decode = decode
}

function module.get_info()
    return parsed_info
end

return module