--[[
  Work In Progress
]]

local protect = require "lib/private/protect"

if protect.protect_require() then return end

local module = { }

local SPEAKERS = { }

local aliveSpeakersCount = 0
local playingStreamsCount = 0

local NEXT_ID = 1

local function ensureSpeaker(id)
    if not speakers[id] then
        error("undefined speaker with id '"..id.."'")
    end
end

local function ensureArgs(args, names)
    for i = 1, #args do
        if not args[i] then
            error("'"..names[i].."' argument is undefined")
        end
    end
end

local function checkVolPitch(num, name)
    if num < 0 or num > 1 then
        error("invalid "..name)
    end
end

function module.get_channel(speaker)
    ensureSpeaker(speaker)

    return SPEAKERS[speaker].channel
end

function module.is_2d(speaker)
    ensureSpeaker(speaker)

    return SPEAKERS[speaker].x == nil
end

local function basePlay(name, x, y, z, volume, pitch, channel, loop)
    ensureArgs(
        {
            name, volume, pitch
        },

        {
            'name', 'volume', 'pitch'
        }
    )

    channel = channel or 'regular'
    
    if loop == nil then loop = false end

    local sound = {
        path = name,
        x = x, y = y, z = z,
        volume = volume,
        pitch = pitch,
        channel = channel,
        loop = loop,
        offsetTime = time.uptime()
    }

    local id = NEXT_ID

    SPEAKERS[id] = sound

    NEXT_ID = NEXT_ID + 1

    aliveSpeakersCount = aliveSpeakersCount + 1

    return id, sound
end

function module.play_stream(name, x, y, z, volume, pitch, channel, loop)
    ensureArgs(
        { x, y, z },
        { 'x', 'y', 'z' }
    )

    local id, sound = basePlay(name, x, y, z, volume, pitch, channel, loop)

    sound.isStream = true
    playingStreamsCount = playingStreamsCount + 1

    return id
end

function module.play_stream_2d(name, volume, pitch, channel, loop)
    local id, sound = basePlay(name, nil, nil, nil, volume, pitch, channel, loop)

    sound.isStream = true
    playingStreamsCount = playingStreamsCount + 1

    return id
end

function module.play_sound(...)
    local id, _ = basePlay(...)

    return id
end

function module.play_sound_2d(name, volume, pitch, channel, loop)
    local id, _ = basePlay(name, nil, nil, nil, volume, pitch, channel, loop)

    return id
end

function module.get_velocity(speaker)
    ensureSpeaker(speaker)

    local t = SPEAKERS[speaker]

    return t.velX, t.velY, t.velZ
end

function module.set_velocity(speaker, x, y, z)
    ensureSpeaker(speaker)

    if not (x and y and z) then
        error 'invalid speaker velocity'
    end

    local t = SPEAKERS[speaker]

    t.velX, t.velY, t.velZ = x, y, z
end

function module.get_position(speaker)
    ensureSpeaker(speaker)

    local t = SPEAKERS[speaker]

    return t.x, t.y, t.z
end

function module.set_position(speaker, x, y, z)
    ensureSpeaker(speaker)

    if not (x and y and z) then
        error 'invalid speaker position'
    end

    local t = SPEAKERS[speaker]

    t.x, t.y, t.z = x, y, z
end

function module.get_pitch(speaker)
    ensureSpeaker(speaker)

    return SPEAKERS[speaker].pitch
end

function module.set_pitch(speaker, pitch)
    ensureSpeaker(speaker)

    checkVolPitch(pitch, 'pitch')

    SPEAKERS[speaker].pitch = pitch
end

function module.get_volume(speaker)
    ensureSpeaker(speaker)

    return SPEAKERS[speaker].volume
end

function module.set_volume(speaker, volume)
    ensureSpeaker(speaker)

    checkVolPitch(volume, "volume")

    SPEAKERS[speaker].volume = volume
end

function module.is_loop(speaker)
    ensureSpeaker(speaker)

    return SPEAKERS[speaker].loop
end

function module.set_loop(speaker, loop)
    ensureSpeaker(speaker)

    SPEAKERS[speaker].loop = loop
end

function module.resume(speaker)
    ensureSpeaker(speaker)

    local t = SPEAKERS[speaker]

    if not t.paused then
        return
    end

    t.offsetTime = time.uptime() - t.timeOnPaused
    t.paused = false

    if t.isStream then
        playingStreamsCount = playingStreamsCount + 1
    end
end

function module.pause(speaker)
    ensureSpeaker(speaker)

    local t = SPEAKERS[speaker]

    t.timeOnPaused = module.get_time(speaker)
    t.paused = true

    if t.isStream then
        playingStreamsCount = playingStreamsCount - 1
    end
end

function module.stop(speaker)
    ensureSpeaker(speaker)

    if SPEAKERS[speaker].isStream and not SPEAKERS[speaker].paused then
        playingStreamsCount = playingStreamsCount - 1
    end

    aliveSpeakersCount = aliveSpeakersCount - 1

    SPEAKERS[speaker] = nil
end

function module.get_time(speaker)
    ensureSpeaker(speaker)

    return SPEAKERS[speaker].paused and SPEAKERS[speaker].timeOnPaused or (time.uptime() - SPEAKERS[speaker].offsetTime)
end

function module.set_time(speaker, _time)
    ensureSpeaker(speaker)

    if _time < 0 then
        error "invalid speaker time"
    end

    SPEAKERS[speaker].offsetTime = time.uptime() - _time
end

function module.get_duration(speaker)
    ensureSpeaker(speaker)
    
    logger.log("'audio.get_duration' function in the API always returns 0 for technical reasons", 'W')

    return 0
end

function module.count_speakers()
    return aliveSpeakersCount
end

function module.count_streams()
    return playingStreamsCount
end

function module.get_in_radius(x, y, z, radius)
    local speakers = {}

    for id, speaker in pairs(SPEAKERS) do
        local sx, sy, sz = speaker.x, speaker.y, speaker.z
        if pos then
            if math.euclidian3D(x, y, z, sx, sy, sz) <= radius then
                table.insert(speakers, id)
            end
        end
    end

    return speakers
end

return module