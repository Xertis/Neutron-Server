local protect = require "lib/private/protect"

if protect.protect_require() then return end

local module = {}

local WEATHERS = {}
local MAX_WID = 1
local READ_PATH = string.format("user:worlds/%s/weather.json", CONFIG.game.main_world)
local WRITE_PATH = "world:weather.json"

local function tohex(num)
    return string.format("%x", num)
end

events.on("server:save", function ()
    file.write(
        WRITE_PATH,
        json.tostring({
            max_wid = MAX_WID,
            ["weather-conditions"] = WEATHERS
        })
    )
end)

function module.load()
    if file.exists(READ_PATH) then
        local data = json.parse(file.read(READ_PATH))
        MAX_WID = data.max_wid
        WEATHERS = data["weather-conditions"]
    end
end

function module.set_weather(x, z, radius, duration, on_finished, conf)
    local wid = MAX_WID
    print(MAX_WID)
    WEATHERS[tohex(MAX_WID)] = {
        x = x,
        z = z,
        radius = radius,
        duration = duration,
        on_finished = on_finished,
        weather = conf.weather,
        time_start = time.uptime(),
        time_transition = conf.time,
        name = conf.name,
        wid = wid
    }

    MAX_WID = MAX_WID + 1
    return wid
end

function module.remove_weather(wid)
    WEATHERS[tohex(wid)] = nil
end

function module.get_by_pos(x, z)
    for _, weather in pairs(WEATHERS) do
        if ( weather.time_start + weather.duration < time.uptime() ) and weather.duration ~= -1 then
            module.remove_weather(weather.wid)
            if weather.on_finished then
                weather.on_finished(weather)
            end
            return
        end

        if math.euclidian2D(weather.x, weather.z, x, z) <= weather.radius then
            return weather
        end
    end
end

function module.get_by_wid(wid)
    return WEATHERS[tohex(wid)]
end

module.load()

return module