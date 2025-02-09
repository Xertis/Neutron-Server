
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

function string.first_up(str)
    return (str:gsub("^%l", string.upper))
end

logger = {}

function logger.log(text, type)
    type = type or 'I'
    text = string.first_up(text)

    local source = file.name(debug.getinfo(2).source)
    local out = '[SERVER: ' .. string.left_padding(source, 12) .. '] ' .. text

    local uptime = tostring(math.round(time.uptime(), 8))
    local deltatime = tostring(math.round(time.delta(), 8))

    local timestamp = '[' .. type .. '] ' .. uptime .. ' | ' .. deltatime

    print(timestamp .. string.left_padding(out, #out+33-#timestamp))
end