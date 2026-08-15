local Messages = import "api/v2/messages"
local chunks = import "core/sandbox/managers/chunks"

local next_event_id = 0

local predicted_events = {}

local PredictedEvent = {}
PredictedEvent.__index = PredictedEvent

local Instance = {}
Instance.__index = Instance

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

    config = {
        on_start = config.on_start or function(_, __) end,
        on_interrupt = config.on_interrupt or function(_, __) end,
        on_tick = config.on_tick or function(_, __) end,
        on_finish = config.on_finish or function(_, __) end,
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

            self.instances[event_id] = Instance.new(self, event_id, client, packet.data, 0)
        end
        self.messages.s_ack:tell(client, {
            request_id = packet.request_id,
            event_id = event_id,
            accepted = accepted and true or false
        })
    end)

    self.messages.c_interrupt:on(function(client, packet)
        local instance = self.instances[packet.event_id]
        if instance and client == instance.client then
            self.config.on_interrupt(client, instance)
            instance:interrupt()
        end
    end)

    self = setmetatable(self, PredictedEvent)

    predicted_events[#predicted_events+1] = self

    return self
end

function PredictedEvent:tick()
    for event_id, instance in pairs(self.instances) do
        if instance.active then
            local progress = self.config.on_tick(instance.client, instance)
            instance:set_progress(progress)
            instance:sync()

            if progress >= 1 then
                self.config.on_finish(instance.client, instance)
                instance:finish()
                self.instances[event_id] = nil
            end
        else
            self.instances[event_id] = nil
        end
    end
end

function PredictedEvent:process(client)
    local player_obj = client.player

    for event_id, instance in pairs(self.instances) do
        if instance.active and instance.client ~= client then
            local x, z = math.floor(instance.data.pos[1] / 16), math.floor(instance.data.pos[3] / 16)
            local is_loaded = chunks.is_loaded(player_obj, x, z)
            local observing = player_obj.predicted_observers[event_id]

            if is_loaded and not observing then
                player_obj.predicted_observers[event_id] = true
                self.messages.s_observe_start:tell(client, {
                    event_id = event_id,
                    progress = instance.progress,
                    data = instance.data
                })
            elseif not is_loaded and observing then
                player_obj.predicted_observers[event_id] = nil
            end
        end
    end
end

function Instance.new(predicted, event_id, client, data, progress)
    return setmetatable({
        event_id = event_id,
        client = client,
        data = data,
        start_time = time.uptime(),
        progress = progress,
        predicted = predicted,
        active = true
    }, Instance)
end

function Instance:interrupt()
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

function Instance:finish()
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

function Instance:sync()
    if not self.active then return end

    self.predicted.messages.s_progress:selective_echo({
        event_id = self.event_id,
        progress = self.progress
    }, function(client)
        if client == self.client then return true end
        return client.player.predicted_observers[self.event_id] == true
    end)
end

function Instance:set_progress(progress)
    if not self.active then return end
    self.progress = progress
end

function Instance:get_progress()
    return self.progress
end

function Instance:get_elapsed()
    local now = time.uptime()
    return now - self.start_time
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
