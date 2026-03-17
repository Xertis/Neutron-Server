---
-- Стейт-машина с расширенными возможностями для управления состояниями.
-- @class state_machine
local state_machine = {}
state_machine.__index = state_machine

--- Создает новую стейт-машину.
-- @return state_machine Новый экземпляр стейт-машины.
function state_machine.new()
    local self = setmetatable({}, state_machine)


    self.states = {} -- Таблица всех состояний, добавленных в стейт-машину.
    self.current_state = nil -- Текущее активное состояние.
    self.on_transition_start = nil -- Колбек, вызываемый в начале перехода.
    self.on_transition_end = nil -- Колбек, вызываемый в конце перехода.
    self.on_state_change = nil -- Колбек, вызываемый при изменении состояния.


    return self
end

--- Добавляет новое состояние в стейт-машину.
-- @param name string Имя состояния.
-- @param state table Таблица с обработчиками для состояния (on_enter, on_exit, on_event).
function state_machine:add_state(name, state)
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
function state_machine:set_on_transition_start(callback)
    self.on_transition_start = callback
end

--- Устанавливает колбек для конца перехода.
-- @param callback function Функция, вызываемая после завершения перехода между состояниями.
function state_machine:set_on_transition_end(callback)
    self.on_transition_end = callback
end

--- Устанавливает колбек для изменения состояния.
-- @param callback function Функция, вызываемая при изменении текущего состояния.
function state_machine:set_on_state_change(callback)
    self.on_state_change = callback
end

--- Переходит в указанное состояние.
-- @param state_name string Имя состояния, в которое нужно перейти.
function state_machine:transition_to(state_name)
    assert(self.states[state_name], "Состояние не найдено: " .. tostring(state_name))

    if self.on_transition_start then
        self.on_transition_start(self.current_state, state_name)
    end

    if self.current_state then
        local exit_callback = self.states[self.current_state].on_exit
        if exit_callback then
            exit_callback()
        end
    end

    self.current_state = state_name

    if self.on_state_change then
        self.on_state_change(state_name)
    end

    local enter_callback = self.states[self.current_state].on_enter
    if enter_callback then
        enter_callback()
    end

    if self.on_transition_end then
        self.on_transition_end(state_name)
    end
end

--- Обрабатывает событие в текущем состоянии.
-- @param event any Событие, передаваемое в обработчик текущего состояния.
function state_machine:handle_event(event)
    assert(self.current_state, "Текущее состояние не установлено")
    
    local state = self.states[self.current_state]
    local event_handler = state.on_event

    if event_handler then
        local next_state = event_handler(event)
        if next_state and self.states[next_state] then
            self:transition_to(next_state)
        end
    end
end


return state_machine
-- Пример использования
-- local sm = state_machine:new()

-- -- Установка колбеков
-- sm:set_on_transition_start(function(from, to)
--     print("Начало перехода от", from, "к", to)
-- end)

-- sm:set_on_transition_end(function(new_state)
--     print("Переход завершен. Новое состояние:", new_state)
-- end)

-- sm:set_on_state_change(function(state)
--     print("Состояние изменено на:", state)
-- end)

-- -- Добавление состояний
-- sm:add_state("idle", {
--     on_enter = function()
--         print("Вошли в состояние 'idle'")
--     end,
--     on_exit = function()
--         print("Выход из состояния 'idle'")
--     end,
--     on_event = function(event)
--         if event == "start" then
--             return "running"
--         end
--     end
-- })

-- sm:add_state("running", {
--     on_enter = function()
--         print("Вошли в состояние 'running'")
--     end,
--     on_exit = function()
--         print("Выход из состояния 'running'")
--     end,
--     on_event = function(event)
--         if event == "stop" then
--             return "idle"
--         end
--     end
-- })

-- -- Переходы и обработка событий
-- sm:transition_to("idle")
-- sm:handle_event("start")
-- sm:handle_event("stop")
