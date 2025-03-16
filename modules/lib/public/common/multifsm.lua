-- Мульти-версия FSM для работы с несколькими клиентами.
-- @class multi_state_machine
local multi_state_machine = {}
multi_state_machine.__index = multi_state_machine

--- Создает новую мульти-версию FSM.
-- @return multi_state_machine Новый экземпляр FSM.
function multi_state_machine.new()
    local self = setmetatable({}, multi_state_machine)

    self.states = {} -- Таблица всех состояний, добавленных в FSM.
    self.client_states = {} -- Таблица состояний для каждого клиента.
    self.on_transition_start = nil -- Колбек, вызываемый в начале перехода.
    self.on_transition_end = nil -- Колбек, вызываемый в конце перехода.
    self.on_state_change = nil -- Колбек, вызываемый при изменении состояния.
    self.default_state = nil
    self.client_data = {}

    return self
end

--- Добавляет новое состояние в FSM.
-- @param name string Имя состояния.
-- @param state table Таблица с обработчиками для состояния (on_enter, on_exit, on_event).
function multi_state_machine:add_state(name, state)
    assert(name, "Имя состояния не может быть nil")
    assert(type(state) == "table", "Состояние должно быть таблицей")
    self.states[name] = {
        on_enter = state.on_enter or function() end, -- Обработчик входа в состояние.
        on_exit = state.on_exit or function() end, -- Обработчик выхода из состояния.
        on_event = state.on_event or function() end -- Обработчик событий в состоянии.
    }
end

--- Устанавливает колбек для начала перехода.
-- @param callback function Функция, вызываемая в начале перехода между состояниями.
function multi_state_machine:set_on_transition_start(callback)
    self.on_transition_start = callback
end

--- Устанавливает колбек для конца перехода.
-- @param callback function Функция, вызываемая после завершения перехода между состояниями.
function multi_state_machine:set_on_transition_end(callback)
    self.on_transition_end = callback
end

--- Устанавливает колбек для изменения состояния.
-- @param callback function Функция, вызываемая при изменении текущего состояния.
function multi_state_machine:set_on_state_change(callback)
    self.on_state_change = callback
end

--- Переходит в указанное состояние для конкретного клиента.
-- @param client_id any Уникальный идентификатор клиента.
-- @param state_name string Имя состояния, в которое нужно перейти.
function multi_state_machine:transition_to(client_id, state_name, ...)
    assert(self.states[state_name], "Состояние не найдено: " .. tostring(state_name))

    local current_state = self.client_states[client_id]

    if self.on_transition_start then
        self.on_transition_start(client_id, current_state, state_name)
    end

    if current_state then
        local exit_callback = self.states[current_state].on_exit
        if exit_callback then
            exit_callback(client_id)
        end
    end

    self.client_states[client_id] = state_name

    if self.on_state_change then
        self.on_state_change(client_id, state_name)
    end

    local enter_callback = self.states[state_name].on_enter
    if enter_callback then
        local state = enter_callback(client_id, ...)

        if state then
            self:transition_to(client_id, state, ...)
            return
        end
    end

    if self.on_transition_end then
        self.on_transition_end(client_id, state_name)
    end
end

--- Обрабатывает событие для конкретного клиента.
-- @param client_id any Уникальный идентификатор клиента.
-- @param event any Событие, передаваемое в обработчик текущего состояния.
function multi_state_machine:handle_event(client_id, event)
    local current_state = self.client_states[client_id] or self.default_state
    assert(current_state, "Текущее состояние не установлено для клиента: " .. tostring(client_id))

    local state = self.states[current_state]
    local event_handler = state.on_event

    if event_handler then
        local returns = {event_handler(client_id, event)}

        local next_state = returns[1]
        table.remove(returns, 1)

        if next_state and self.states[next_state] then
            self:transition_to(client_id, next_state, unpack(returns))
        end
    end
end

--- Возвращает текущее состояние клиента.
-- @param client_id any Уникальный идентификатор клиента.
-- @return string Текущее состояние клиента.
function multi_state_machine:get_current_state(client_id)
    return self.client_states[client_id]
end

--- Задаёт стандартное состояние всех клиентов.
-- @param state string Стандартное состояние.
function multi_state_machine:set_default_state(state)
    self.default_state = state
end

return multi_state_machine