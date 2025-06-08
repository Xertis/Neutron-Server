local protect = require "lib/private/protect"

if protect.protect_require() then return end

local bson = require "lib/private/files/bson"

local module = {}

local WEATHERS = {}
local MAX_WID = 1
local READ_PATH = string.format("user:worlds/%s/server_resources/weather.bson", CONFIG.game.main_world)
local WRITE_PATH = "world:server_resources/weather.bson"

local WEATHER_SEED_START = nil
local WEATHER_SEED_END = nil
local WEATHER_CYCLE_DURATION = 20000  -- Полный цикл 20 часов (10 часов в каждую сторону)
local LAST_CYCLE_UPDATE = 0           -- Время последнего обновления цикла


local function generate_weather_seeds()
    local current_cycle = math.floor(world.get_total_time() / WEATHER_CYCLE_DURATION)
    local combined_seed = bit.bxor(world.get_seed(), current_cycle)

    WEATHER_SEED_START = bit.band(combined_seed, 0x598CC129D23)
    WEATHER_SEED_END = bit.band(combined_seed,   0x6D82EDA8C33)
    LAST_CYCLE_UPDATE = current_cycle * WEATHER_CYCLE_DURATION
end


local function get_weather_map(x, z, gen_map)
    local current_time = world.get_total_time()

    if not WEATHER_SEED_START or math.floor(current_time / WEATHER_CYCLE_DURATION) > math.floor(LAST_CYCLE_UPDATE / WEATHER_CYCLE_DURATION) then
        generate_weather_seeds()
    end

    local time_in_cycle = current_time % WEATHER_CYCLE_DURATION
    local half_cycle = WEATHER_CYCLE_DURATION / 2
    local progress = 0.0

    if time_in_cycle < half_cycle then
        progress = time_in_cycle / half_cycle
    else
        progress = 1.0 - ((time_in_cycle - half_cycle) / half_cycle)
    end

    local start_map = gen_map(x, z, WEATHER_SEED_START)
    local end_map = gen_map(x, z, WEATHER_SEED_END)

    start_map:mixin(end_map, progress)
    return start_map
end

events.on("server:save", function ()
    file.mktree(
        WRITE_PATH,
        bson.serialize({
            max_wid = MAX_WID,
            ["weather-conditions"] = table.to_serializable(WEATHERS)
        })
    )
end)

function module.load()
    if file.exists(READ_PATH) then
        local data = bson.deserialize(file.read_bytes(READ_PATH))
        MAX_WID = data.max_wid
        WEATHERS = data["weather-conditions"]
    end
end

function module.set_weather(region, conf)
    local wid = MAX_WID
    local wdata = {
        weather = conf.weather,
        time_start = world.get_total_time(),
        time_transition = conf.time,
        name = conf.name or '',
        type = region.type,
        wid = wid
    }

    if region.type == "point" then
        wdata.x = region.x
        wdata.z = region.z
        wdata.radius = region.radius
        wdata.duration = region.duration
        wdata.on_finished = region.on_finished
    elseif region.type == "heightmap" then
        wdata.heightmap_generator = region.heightmap_generator
        wdata.range = region.range
    else
        error("Invalid weather type: " .. tostring(region.type))
    end

    WEATHERS[tohex(MAX_WID)] = wdata

    MAX_WID = MAX_WID + 1
    return wid
end

function module.remove_weather(wid)
    WEATHERS[tohex(wid)] = nil
end

local function point_get_by_pos(weather, x, z)
    if ( weather.time_start + weather.duration < world.get_total_time() ) and weather.duration ~= -1 then
        module.remove_weather(weather.wid)
        if weather.on_finished then
            weather.on_finished(weather)
        end
        return
    end

    if math.euclidian2D(weather.x, weather.z, x, z) <= weather.radius then
        return weather
    end

    return true
end

local function heightmap_get_by_pos(weather, x, z)
    if not weather.heightmap_generator then
        return true
    end

    local map = get_weather_map(x, z, weather.heightmap_generator)
    local res = map:at({x, z})
    local min, max = weather.range[1], weather.range[2]

    if res >= min and res <= max then
        return weather
    end
    return true
end

function module.get_by_pos(x, z)
    for _, weather in pairs(WEATHERS) do
        local f = nil

        if weather.type == "point" then
            f = point_get_by_pos
        else
            f = heightmap_get_by_pos
        end

        local res = f(weather, x, z)

        if res ~= true then
            return res
        end
    end
end

function module.get_by_wid(wid)
    return WEATHERS[tohex(wid)]
end

module.load()

return module