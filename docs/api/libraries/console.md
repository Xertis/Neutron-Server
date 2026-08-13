# console

**Содержание**
- [Создание команд](#создание-команд)
- [Машина состояний](#машина-состояний)
- [Остальные функции](#остальные-функции)

## Создание команд

```lua
api.console.set_command(
    схема: string,
    разрешения: table<table>,
    исполнитель: function,
    [опционально] можно_ли_использовать_без_авторизации: boolean
)
```

### Синтаксис схемы

```
название: параметры -> описание команды
```

Параметры разделяются через `, ` и имеют следующий синтаксис:

```
название=<тип>    -- Обязательный аргумент
название=[тип]    -- Необязательный аргумент
```

> [!WARNING]
> Необязательные аргументы должны идти всегда после обязательных.

### Доступные типы

| Тип | Описание |
|-----|----------|
| `number` | Число |
| `string` | Строка |
| `boolean` | true/false |
| `table` | Таблица (в консоль вводится в формате JSON) |

### Примеры схем

```python
time_set: time= -> Changes day time
block_set: x=, y=, z=, id=[number] -> Set Block
```

### Полный пример

```lua
api.console.set_command("time_set: time= -> Changes day time", {permissions={"time_management"}}, function(args, client)
    local time = args.time
    local account = client.account

    if not time then
        console.tell(string.format('%s Incorrect time entered!', console.colors.red), client)
        return
    end

    local status = sandbox.set_day_time(time)

    if status then
        console.echo(string.format('%s [%s] Time has been changed to: %s', console.colors.yellow, account.username, time))
    else
        console.tell(string.format("%s Incorrect time entered!", console.colors.red), client)
    end
end)
```

## Машина состояний

Консоль поддерживает машины состояний. Пока пользователь находится в состоянии, все его сообщения (включая команды) перехватывает обработчик этого состояния.

### Создание состояния

```lua
api.console.create_state(name: string) -> State
```

### Установка состояния клиенту

```lua
api.console.set_state(state: State, client: Client)
```

### Обработчик состояния

```lua
api.console.set_state_handler(
    state: State,
    handler: function(message: string, state: State, client: Client)
)
```

### Методы State

| Метод | Описание |
|-------|----------|
| `state:move_to(new_state: State)` | Переход между состояниями. |
| `state:clear()` | Выход из состояния. |
| `state:update_data(key: string, data: any)` | Сохранение данных в хранилище состояния. |
| `state:get_data([key: string]) -> any \| nil` | Получение данных. Если `key` не указан, возвращает всю таблицу. |

### Пример машины состояний

```lua
local s_name = console.create_state("Name")
local s_age = console.create_state("Age")
local s_food = console.create_state("Food")

console.set_command("test: -> Test", {}, function(args, client)
    console.tell("Введи своё имя", client)
    console.set_state(s_name, client)
end)

console.set_state_handler(s_name, function(message, state, client)
    state:update_data("name", message)
    state:move_to(s_age)
    console.tell("Введи свой возраст", client)
end)

console.set_state_handler(s_age, function(message, state, client)
    state:update_data("age", message)
    state:move_to(s_food)
    console.tell("Введи своё любимое блюдо", client)
end)

console.set_state_handler(s_food, function(message, state, client)
    local name = state:get_data("name")
    local age = state:get_data("age")
    console.tell(string.format("Тебя зовут %s, тебе %s лет, твоё любимое блюдо - %s", name, age, message), client)
    state:clear()
end)
```

## Остальные функции

```lua
-- Отправка сообщения определённому клиенту
api.console.tell(message: string, client: Client)

-- Отправка сообщения всем клиентам
api.console.echo(message: string)

-- Выполнение команд
api.console.execute(message: string, client: Client)
```

### Цвета

```lua
api.console.colors = {
    red    = "[#ff0000]",
    yellow = "[#ffff00]",
    blue   = "[#0000FF]",
    black  = "[#000000]",
    green  = "[#00FF00]",
    white  = "[#FFFFFF]"
}
```
