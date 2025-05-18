Для работы с командным интерпретатором предоставляется библиотека **console**.
## Создание команд

Для создания команды консоли используется следующая функция:

```python
api.console.add_command(схема: str, разрешения: table< table<str> >, исполнитель: function)
```

Схема имеет следующий синтаксис:

```
название: параметры -> описание команды
```

Параметры разделяются через:  `, ` и имеют следующий синтаксис:

```
название=<тип>      Обязательный аргумент
название=[тип]      Необязательный аргумент
```

>[!WARNING]
>Необязательные аргументы должны идти всегда после обязательных

Доступные типы:
- **number** - число
- **string** - строка
- **boolean** - true/false
- **table** - таблица (в консоль вводится в формате json)

### Примеры схем команд

Схемы стандартных команд можно найти в файле `multiplayer/server/chat/commands`

**Примеры:**

```python
time_set: time=<any> -> Changes day time
block_set: x=<number>, y=<number>, z=<number>, id=[number] -> Set Block
```

Полный lua код создания команды:

```lua
api.console.set_command("time_set: time=<any> -> Changes day time", {server={"time_management"}}, function (args, client)
    local time = args.time
    local account = client.account

    if not time then
        console.tell(string.format('%s Incorrect time entered! Please enter a number between 0 and 1', console.colors.red), client)
        return
    end

    local status = sandbox.set_day_time(time)

    if status then
        console.echo(string.format('%s [%s] Time has been changed to: %s', console.colors.yellow, account.username, time))
    else
        console.tell(string.format("%s Incorrect time entered! Please enter a number between 0 and 1", console.colors.red), client)
    end
end)
```

Проверку и приведение типов интерпретатор команд производит автоматически.

## Машина состояний

>Коносль в Neutron поддерживает машины состояний, пока пользователь находится в каком-либо состоянии, все его сообщения (включая команды) перехватывает обработчик, отвечающий за эти состояния.

1. **Создание состояния по имени**
```lua
api.console.create_state(name: string) -> State
```

2. **Установка состояния клиенту**
```lua
api.console.set_state(state: State, client: Client)
```

3. **Объявление обработчика состояния**
```lua
api.console.set_state_handler(
   state: State, 
   handler: function (message: string, state: State, client: Client)
)
```

### Методы **State**

1. **Переход между состояниями**
```lua
state:move_to(new_state: State)
```

2. **Выход из состояния**
```lua
state:clear()
```

3. **Сохранение данных в хранилище состояния**
```lua
state:update_data(key: String, data: Any)
```

4. **Получение данных из хранилища состояний**
```lua
state:get_data([опционально] key: String) -> Any | nil
```
Если **key** не указан, вернёт всю таблицу хранилища

## Пример использования машины
```lua
local s_name = console.create_state("Name")
local s_age = console.create_state("Age")
local s_food = console.create_state("Food")

console.set_command("test: -> Test", {}, function (args, client)
    console.tell("Введи своё имя", client)
    console.set_state(s_name, client)
end)

console.set_state_handler(s_name, function (message, state, client)
    state:update_data("name", message)
    state:move_to(s_age)
    console.tell("Введи свой возраст", client)
end)

console.set_state_handler(s_age, function (message, state, client)
    state:update_data("age", message)
    state:move_to(s_food)
    console.tell("Введи своё любимое блюдо", client)
end)

console.set_state_handler(s_food, function (message, state, client)
    local name = state:get_data("name")
    local age = state:get_data("age")
    console.tell(string.format("Тебя зовут %s, тебе %s лет, твоё любимое блюдо - %s", name, age, message), client)
    state:clear()
end)
```

### Остальные функции

1. **Отправка сообщения определённому клиенту:**
```lua
api.console.tell(message: string, client: Client)
```
   - Отправляет в чат клиента **client** сообщение **message**

2. **Отправка сообщения всем клиентам:**
```lua
api.console.echo(message: string)
```
   - Отправляет в чат всем клиентам сообщение **message**

3. **Выполнение команд:**
```lua
api.console.execute(message: string, client: Client)
```
   - Выполняет команду из **message**, как будто бы его отправил в консоль **client**

4. **Цвета**
```lua
api.console.colors = {
    red = "[#ff0000]",
    yellow = "[#ffff00]",
    blue = "[#0000FF]",
    black = "[#000000]",
    green = "[#00FF00]",
    white = "[#FFFFFF]"
}
```
- **console** хранит в себе эти заготовленные цвета, в **console.tell / console.echo** желательно использовать именно их
