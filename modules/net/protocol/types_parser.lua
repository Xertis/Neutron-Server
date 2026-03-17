local PATH_TO_PARSER = PACK_ID .. ":resources/protocol/parsers.lua"
local module = {}

function module.parse_content(content)
    local ENCODE = {}
    local DECODE = {}

    local read_start_pos = content:find("--@READ_START")
    if not read_start_pos then
        return ENCODE, DECODE
    end

    local remaining_content = content:sub(read_start_pos + #"--@READ_START")

    local block_pattern = "%-%-%s*@([%w_]+)%.([%w]+)([%s%S]-)do([%s%S]-)end %-%-@"

    remaining_content = remaining_content .. "\n--@"

    for block_type, operation, header, code in remaining_content:gmatch(block_pattern) do
        local variables = {}
        local vars_part = header:match("VARIABLES%s+([^\n]*)")
        if vars_part then
            vars_part = vars_part:gsub("%-%-.*", ""):gsub("^%s*(.-)%s*$", "%1")
            if vars_part ~= "" then
                for var in vars_part:gmatch("%S+") do
                    table.insert(variables, var)
                end
            end
        end

        local to_action, to_var = header:match("TO_([%w_]+)%s+([%w_]+)")

        local foreign = header:match("FOREIGN") and true or nil

        local entry = {
            VARIABLES = variables,
            code = code
        }

        if foreign then entry.FOREIGN = foreign end

        if operation == "write" then
            entry.TO_SAVE = to_var or ""
            ENCODE[block_type] = entry
        elseif operation == "read" then
            entry.TO_LOAD = to_var or ""
            DECODE[block_type] = entry
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
