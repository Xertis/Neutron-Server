Для работы с командным интерпретатором предоставляется библиотека **console**.
## Создание команд

Для создания команды консоли используется следующая функция:

```python
api.console.add_command(схема: str, разрешения: table[str], исполнитель: function)
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
api.console.set_command("time_set: time=<any> -> Changes day time", {"time_management"}, function (args, client)
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

## Остальные функции

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
3. **Цвета**
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
