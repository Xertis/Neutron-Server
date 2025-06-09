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

    local block_pattern = "%-%-%s*@([%w_]+)%.([%w]+)([%s%S]-)do([%s%S]-)end%-%-@"

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

        local to_looped = header:match("TO_LOOPED%s+([%w_]+)") or nil
        local len = 0

        local bits = header:match("LENBITS%s+([%w_]+)") or 0
        local bytes = header:match("LENBYTES%s+([%w_]+)") or 0

        if bits == 0 and bytes == 0 then
            len = -1
        else
            len = bits + (bytes * 8)
        end

        local entry = {
            VARIABLES = variables,
            code = code,
            len = len
        }

        if operation == "write" then
            entry.TO_SAVE = to_var or ""
            if to_looped then entry.TO_LOOPED = to_looped end
            ENCODE[block_type] = entry
        elseif operation == "read" then
            entry.TO_LOAD = to_var or ""
            if to_looped then entry.TO_LOOPED = to_looped end
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