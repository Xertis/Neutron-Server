local audio_manager = start_require("server:lib/private/gfx/audio_manager")
local module = {}

local defFuncs = {
    "stop", "pause", "resume", "set_loop", "is_loop", "get_volume",
    "set_volume", "get_pitch", "set_pitch", "get_time", "set_time",
    "get_position", "set_position", "get_velocity", "set_velocity",
    "get_duration", "count_speakers", "count_streams", "get_time_left",
    "register_duration"
}

local playFuncs = {
    "play_stream", "play_stream_2d", "play_sound", "play_sound_2d"
}

local Speaker = {}
Speaker.__index = Speaker

function Speaker.new(id)
    local self = setmetatable({}, Speaker)

    self.id = id

    return self
end

function Speaker:get_position()
    return audio_manager.get_position(self.id)
end

function Speaker:set_position(x, y, z)
    audio_manager.set_position(self.id, x, y, z)
end

function Speaker:get_velocity()
    return audio_manager.get_velocity(self.id)
end

function Speaker:set_velocity(x, y, z)
    audio_manager.set_velocity(self.id, x, y, z)
end

function Speaker:stop()
    audio_manager.stop(self.id)
end

function Speaker:pause()
    audio_manager.pause(self.id)
end

function Speaker:resume()
    audio_manager.resume(self.id)
end

function Speaker:is_loop()
    return audio_manager.is_loop(self.id)
end

function Speaker:set_loop(loop)
    audio_manager.set_loop(self.id, loop)
end

function Speaker:get_volume()
    return audio_manager.get_volume(self.id)
end

function Speaker:set_volume(volume)
    audio_manager.set_volume(self.id, volume)
end

function Speaker:get_pitch()
    return audio_manager.get_pitch(self.id)
end

function Speaker:set_pitch(pitch)
    return audio_manager.set_pitch(self.id, pitch)
end

function Speaker:get_time()
    return audio_manager.get_time(self.id)
end

function Speaker:set_time(time)
    return audio_manager.set_time(self.id, time)
end

function Speaker:get_time_left()
    return audio_manager.get_time_left(self.id)
end

function Speaker:get_duration()
    return audio_manager.get_duration(self.id)
end

for _, name in ipairs(defFuncs) do
    module[name] = audio_manager[name]
end

for _, name in ipairs(playFuncs) do
    local func = audio_manager[name]

    module[name] = function(...)
        local id = func(...)

        return id, Speaker.new(id)
    end
end

return module