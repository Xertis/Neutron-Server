local List = {}

-- Создает новый список
function List.new()
    return {
        first = 0, -- Индекс первого элемента
        last = -1  -- Индекс последнего элемента
    }
end

-- Проверяет, пуст ли список
function List.is_empty(list)
    return list.first > list.last
end

-- Добавляет элемент в начало списка
function List.pushleft(list, value)
    list.first = list.first - 1
    list[list.first] = value
end

-- Добавляет элемент в конец списка
function List.pushright(list, value)
    list.last = list.last + 1
    list[list.last] = value
end

-- Удаляет и возвращает элемент из начала списка
function List.popleft(list)
    if List.is_empty(list) then
        error("List is empty")
    end
    local first = list.first
    local value = list[first]
    list[first] = nil -- Очищаем ссылку для предотвращения утечки памяти
    list.first = first + 1
    return value
end

-- Удаляет и возвращает элемент из конца списка
function List.popright(list)
    if List.is_empty(list) then
        error("List is empty")
    end
    local last = list.last
    local value = list[last]
    list[last] = nil -- Очищаем ссылку для предотвращения утечки памяти
    list.last = last - 1
    return value
end

return List

