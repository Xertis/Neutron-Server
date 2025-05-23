local weather_manager = start_require "lib/private/weather/weather_manager"
local module = {}


local weather_mt = {
    __index = {
        remove = function(self)
            weather_manager.remove_weather(self.wid)
        end,

        move = function(self, x, z)
            local weather = weather_manager.get_by_wid(self.wid)
            if weather then
                weather.x = x
                weather.z = z
            end
        end,

        get_config = function(self)
            local weather = weather_manager.get_by_wid(self.wid)
            if weather then
                return weather.weather
            end
        end,

        get_wid = function(self)
            return self.wid
        end,

        set_radius = function(self, radius)
            local weather = weather_manager.get_by_wid(self.wid)
            if weather then
                weather.radius = radius
            end
        end,

        set_duration = function(self, duration)
            local weather = weather_manager.get_by_wid(self.wid)
            if weather then
                weather.duration = duration
            end
        end,

        is_active = function(self)
            return weather_manager.get_by_wid(self.wid) ~= nil
        end
    }
}

local function create_weather_object(weather_data)
    return setmetatable({
        wid = weather_data.wid,
        x = weather_data.x,
        z = weather_data.z,
        radius = weather_data.radius,
        duration = weather_data.duration,
        config = weather_data.weather,
        name = weather_data.name,
        time_start = weather_data.time_start,
        time_transition = weather_data.time_transition
    }, weather_mt)
end

function module.create(x, z, radius, duration, on_finished, conf)
    local wid = weather_manager.set_weather(x, z, radius, duration, on_finished, conf)

    return create_weather_object({
        wid = wid,
        x = x,
        z = z,
        radius = radius,
        duration = duration,
        weather = conf.weather,
        name = conf.name,
        time_start = time.uptime(),
        time_transition = conf.time
    })
end

function module.get(wid)
    local weather_data = weather_manager.get_by_wid(wid)
    if weather_data then
        return create_weather_object(weather_data)
    end
end

function module.get_by_pos(x, z)
    return table.deep_copy(weather_manager.get_by_pos(x, z))
end

return module