local weather_manager = start_require "server:lib/private/gfx/weather_manager"
local module = {}

local weather_mt = {
    __index = {
        remove = function(self)
            weather_manager.remove_weather(self.wid)
        end,

        move = function(self, x, z)
            if self.type ~= "point" then
                error("move() available only for point-type weather", 2)
            end
            local weather = weather_manager.get_by_wid(self.wid)
            if weather then
                weather.x = x
                weather.z = z
                self.x = x
                self.z = z
            end
        end,

        set_radius = function(self, radius)
            if self.type ~= "point" then
                error("set_radius() available only for point-type weather", 2)
            end
            local weather = weather_manager.get_by_wid(self.wid)
            if weather then
                weather.radius = radius
                self.radius = radius
            end
        end,

        set_duration = function(self, duration)
            if self.type ~= "point" then
                error("set_duration() available only for point-type weather", 2)
            end
            local weather = weather_manager.get_by_wid(self.wid)
            if weather then
                weather.duration = duration
                self.duration = duration
            end
        end,

        set_finish_handler = function(self, handler)
            if self.type ~= "point" then
                error("set_finish_handler() available only for point-type weather", 2)
            end
            local weather = weather_manager.get_by_wid(self.wid)
            if weather then
                weather.on_finished = handler
                self.on_finished = handler
            end
        end,

        set_heightmap_generator = function(self, heightmap_generator)
            if self.type ~= "heightmap" then
                error("set_heightmap_generator() available only for heightmap-type weather", 2)
            end
            local weather = weather_manager.get_by_wid(self.wid)
            if weather then
                weather.heightmap_generator = heightmap_generator
                self.heightmap_generator = heightmap_generator
            end
        end,

        set_height_range = function(self, min, max)
            if self.type ~= "heightmap" then
                error("set_height_range() available only for heightmap-type weather", 2)
            end
            local weather = weather_manager_get_by_wid(self.wid)
            if weather then
                weather.range = {min, max}
                self.range = {min, max}
            end
        end,

        get_config = function(self)
            return self.config
        end,

        get_wid = function(self)
            return self.wid
        end,

        get_type = function(self)
            return self.type
        end,

        is_active = function(self)
            return weather_manager.get_by_wid(self.wid) ~= nil
        end
    }
}

local function create_weather_object(weather_data)
    local obj = {
        wid = weather_data.wid,
        config = weather_data.weather,
        name = weather_data.name or '',
        time_start = weather_data.time_start,
        time_transition = weather_data.time_transition,
        type = weather_data.type
    }

    if weather_data.type == "point" then
        obj.x = weather_data.x
        obj.z = weather_data.z
        obj.radius = weather_data.radius
        obj.duration = weather_data.duration
        obj.on_finished = weather_data.on_finished
    elseif weather_data.type == "heightmap" then
        obj.heightmap_generator = weather_data.heightmap_generator
        obj.range = weather_data.range
    end

    return setmetatable(obj, weather_mt)
end

function module.create(region, conf)
    local wid = weather_manager.set_weather(region, conf)

    local weather_data = {
        wid = wid,
        weather = conf.weather,
        name = conf.name or '',
        time_start = time.uptime(),
        time_transition = conf.time,
        type = region.type
    }

    if region.type == "point" then
        weather_data.x = region.x
        weather_data.z = region.z
        weather_data.radius = region.radius
        weather_data.duration = region.duration
        weather_data.on_finished = region.on_finished
    elseif region.type == "heightmap" then
        weather_data.heightmap_generator = region.heightmap_generator
        weather_data.range = region.range
    end

    return create_weather_object(weather_data)
end

function module.get(wid)
    local weather_data = weather_manager.get_by_wid(wid)
    if weather_data then
        return create_weather_object(weather_data)
    end
    return nil
end

function module.get_by_pos(x, z)
    local weather_data = weather_manager.get_by_pos(x, z)
    if weather_data and weather_data.wid then
        return module.get(weather_data.wid)
    end
    return nil
end

return module