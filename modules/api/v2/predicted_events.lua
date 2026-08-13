local Messages = import "api/v2/messages"
local chunks = import "core/sandbox/managers/chunks"

local next_event_id = 0

local predicted_events = {}

local PredictedEvent = {}
PredictedEvent.__index = PredictedEvent

local Instant = {}
Instant.__index = Instant

function PredictedEvent.new(pack, event, schema, config)
    if not schema.pos then
        error("The schema must include a 'pos' field")
    end

    local self = {}

    self.messages = {
        c_start = Messages.new(pack, event, {
            request_id = "var",
            data = schema
        }),
        c_interrupt = Messages.new(pack, event .. "0", {
            event_id = "var"
        }),
        s_ack = Messages.new(pack, event .. "2", {
            request_id = "var",
            event_id = "Nilable<var>",
            accepted = "boolean"
        }),
        s_observe_start = Messages.new(pack, event .. "3", {
            event_id = "var",
            progress = "norm16",
            data = schema
        }),
        s_progress = Messages.new(pack, event .. "4", {
            event_id = "var",
            progress = "norm16"
        }),
        s_finish = Messages.new(pack, event .. "5", {
            event_id = "var"
        }),
        s_interrupt = Messages.new(pack, event .. "6", {
            event_id = "var"
        })
    }

    self.instances = {}
    self.config = config

    self.messages.c_start:on(function(client, packet)
        local pos = packet.data.pos
        local x, z = math.floor(pos[1] / 16), math.floor(pos[3] / 16)

        local accepted = chunks.is_loaded(client.player, x, z) and self.config.on_start(client, packet.data)
        local event_id = nil
        if accepted then
            event_id = next_event_id
            next_event_id = next_event_id + 1

            self.instances[event_id] = Instant.new(self, event_id, client, packet.data, 0)
        end

        self.messages.s_ack:tell(client, {
            request_id = packet.request_id,
            event_id = event_id,
            accepted = accepted and true or false
        })
    end)

    self.messages.c_interrupt:on(function(client, packet)
        local instant = self.instances[packet.event_id]
        if instant and client == instant.client then
            self.config.on_interrupt(client, instant)
            instant:interrupt()
        end
    end)

    self = setmetatable(self, PredictedEvent)

    predicted_events[#predicted_events+1] = self

    return self
end

function PredictedEvent:tick()
    for event_id, instant in pairs(self.instances) do
        if instant.active then
            local progress = self.config.on_tick(instant.client, instant)
            instant:set_progress(progress)
            instant:sync()

            if progress >= 1 then
                self.config.on_finish(instant.client, instant)
                instant:finish()
                self.instances[event_id] = nil
            end
        else
            self.instances[event_id] = nil
        end
    end
end

function PredictedEvent:process(client)
    local player_obj = client.player

    for event_id, instant in pairs(self.instances) do
        if instant.active and instant.client ~= client then
            local x, z = math.floor(instant.data.pos[1] / 16), math.floor(instant.data.pos[3] / 16)
            local is_loaded = chunks.is_loaded(player_obj, x, z)
            local observing = player_obj.predicted_observers[event_id]

            if is_loaded and not observing then
                player_obj.predicted_observers[event_id] = true
                self.messages.s_observe_start:tell(client, {
                    event_id = event_id,
                    progress = instant.progress,
                    data = instant.data
                })
            elseif not is_loaded and observing then
                player_obj.predicted_observers[event_id] = nil
            end
        end
    end
end

function Instant.new(predicted, event_id, client, data, progress)
    return setmetatable({
        event_id = event_id,
        client = client,
        data = data,
        progress = progress,
        predicted = predicted,
        active = true
    }, Instant)
end

function Instant:interrupt()
    if not self.active then return end
    self.active = false

    self.predicted.messages.s_interrupt:selective_echo({
        event_id = self.event_id
    }, function(client)
        if client == self.client then return true end
        local player_obj = client.player
        local observing = player_obj.predicted_observers[self.event_id]
        if observing then
            player_obj.predicted_observers[self.event_id] = nil
        end
        return observing
    end)
end

function Instant:finish()
    if not self.active then return end
    self.active = false

    self.predicted.messages.s_finish:selective_echo({
        event_id = self.event_id
    }, function(client)
        if client == self.client then return true end
        local player_obj = client.player
        local observing = player_obj.predicted_observers[self.event_id]
        if observing then
            player_obj.predicted_observers[self.event_id] = nil
        end
        return observing
    end)
end

function Instant:sync()
    if not self.active then return end

    self.predicted.messages.s_progress:selective_echo({
        event_id = self.event_id,
        progress = self.progress
    }, function(client)
        if client == self.client then return true end
        return client.player.predicted_observers[self.event_id] == true
    end)
end

function Instant:set_progress(progress)
    if not self.active then return end
    self.progress = progress
end

function Instant:get_progress()
    return self.progress
end

events.on("server:client_pipe_start", function(client)
    for i=1, #predicted_events do
        predicted_events[i]:process(client)
    end
end)

events.on("server:main_tick", function ()
    for i=1, #predicted_events do
        predicted_events[i]:tick()
    end
end)

return PredictedEvent
