
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