-- STRING

function string.replace_substr(str1, str2, start, finish)
    if start < 1 or finish > #str1 or start > finish then
        return nil
    end

    local before = str1:sub(1, start - 1)
    local after = str1:sub(finish + 1)

    return before .. str2 .. after
end

function string.first_up(str)
    return (str:gsub("^%l", string.upper))
end

function string.first_low(str)
    return (str:gsub("^%u", string.lower))
end

--- TIME

function time.formatted_time()
    local time_table = os.date("*t")

    local date = string.format("%04d/%02d/%02d", time_table.year, time_table.month, time_table.day)
    local time = string.format("%02d:%02d:%02d", time_table.hour, time_table.min, time_table.sec)

    local milliseconds = string.format("%03d", math.floor((os.clock() % 1) * 1000))

    local utc_offset = os.date("%z")
    if not utc_offset then
        utc_offset = "+0000"
    end

    return string.format("%s %s.%s%s", date, time, milliseconds, utc_offset)
end

--- LOGGER

logger = {}

function logger.log(text, type, only_save, custom_source)
    type = type or 'I'
    type = type:upper()

    text = string.first_low(text)

    local source = file.name(debug.getinfo(2).source)

    if custom_source and source == "main.lua" then
        source = custom_source
    end

    local out = '[' .. string.left_pad(source, 20) .. '] ' .. text

    local uptime = time.formatted_time()

    local timestamp = string.format("[%s] %s", type, uptime)

    local path = "export:server.log"
    local message = timestamp .. string.left_pad(out, #out+33-#timestamp)

    if not only_save then
        print(message)
    end

    if not file.exists(path) then
        file.write(path, "")
    end

    local content = file.read(path)

    if #content > 600000 then
        content = ''
    end

    file.write(path, content .. message .. '\n')
end

function logger.blank()
    print()
end