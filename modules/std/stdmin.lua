server = {}

function string.padding(str, size, char)
    char = char == nil and " " or char
    local padding = math.floor((size - #str) / 2)
    return string.rep(char, padding) .. str .. string.rep(char, padding)
end

function string.left_padding(str, size, char)
    char = char == nil and " " or char
    local left_padding = size - #str
    return string.rep(char, left_padding) .. str
end

function string.right_padding(str, size, char)
    char = char == nil and " " or char
    local right_padding = size - #str
    return str .. string.rep(char, right_padding)
end

function server.log(text, type) -- Костыли, ибо debug.log не поддерживает кастомный вывод
    type = type or 'I'
    local source =file.name(debug.getinfo(2).source)

    local out = '[SERVER: ' .. string.left_padding(source, 12) .. '] ' .. text
    local timestamp = '[' .. type .. '] ' .. tostring(time.uptime()) .. ' | ' .. tostring(time.delta())

    print(timestamp .. string.left_padding(out, #out+33-#timestamp))
end