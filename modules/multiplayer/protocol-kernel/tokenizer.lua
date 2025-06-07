local module = {}

local function tokenize_index(indx)
    if indx == 0 then
        error("Tokenizer index is nil")
    end

    local result = {}
    local base = 26
    local char_offset = string.byte('a') - 1

    while indx > 0 do
        local remainder = indx % base
        if remainder == 0 then
            remainder = base
            indx = indx - base
        end
        table.insert(result, 1, string.char(char_offset + remainder))
        indx = math.floor(indx / base)
    end

    return '_' .. table.concat(result)
end

--Пример токенов
-- {AA = "x"}

function module.variables_replace(func, tokens)
    local patterns = {}
    for old_name, new_name in pairs(tokens) do
        table.insert(patterns, {
            pattern = "%f[%a_]"..old_name.."%f[^%a_]",
            replacement = new_name
        })
    end

    table.sort(patterns, function(a, b)
        return #a.pattern > #b.pattern
    end)

    for _, p in ipairs(patterns) do
        func = func:gsub(p.pattern, p.replacement)
    end

    return func
end

function module.get_tokens(cur_index, variables)
    local tokens = {}
    for indx, var in ipairs(variables) do
        local token = tokenize_index(cur_index + indx)
        tokens[var] = token
    end

    return tokens, cur_index + #variables
end

return module