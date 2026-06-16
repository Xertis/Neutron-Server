## Module (класс)

**Module** - вспомогательный класс для разделения логики мода на:

* **server** - код, доступный только на сервере
* **client** - код, доступный только на клиенте
* **shared** - общий код, доступный на обеих сторонах.

Во время сборки модуля автоматически выбирается соответствующая сторона выполнения и объединяется с общей частью.

---

## Импорт

```lua
local Module = API.utils.classes.module
```

---

## Создание модуля

При создании экземпляра все переданные поля автоматически попадают в секцию **shared**.

```lua
local self = Module({
    method1 = function() end,
    method2 = function() end
})
```

Эквивалентно:

```lua
local self = Module()

function self.shared.method1() end
function self.shared.method2() end
```

---

## Доступ к секциям

Каждый экземпляр модуля содержит три таблицы:

```lua
local server = self.server
local client = self.client
local shared = self.shared
```

---

## Определение методов

### Серверная часть

```lua
function server.save_player()
    print("Server logic")
end
```

### Клиентская часть

```lua
function client.open_ui()
    print("Client logic")
end
```

### Общая часть

```lua
function shared.get_version()
    return "1.0.0"
end
```

---

## Взаимодействие между частями

После сборки методы выбранной стороны становятся частью итогового модуля и могут обращаться к методам.

```lua
function shared.print_message()
    print("Hello")
end

function client.show_message()
    self.print_message()
end
```

На клиенте вызов `show_message()` выполнит общий метод `print_message()`.

---

## Сборка модуля

После объявления всех методов необходимо вызвать `build()`:

```lua
return self:build()
```

Метод автоматически определяет текущую сторону выполнения:

* если мод запущен на сервере — объединяются `server` и `shared`;
* если мод запущен на клиенте — объединяются `client` и `shared`.

---

## Пример

```lua
local Module = API.utils.classes.module

local self = Module()

local server = self.server
local client = self.client
local shared = self.shared

function shared.get_name()
    return "Example Module"
end

function server.get_side()
    return "server"
end

function client.get_side()
    return "client"
end

return self:build()
```

Результат сборки:

### На сервере

```lua
{
    get_name = ...,
    get_side = function() return "server" end
}
```

### На клиенте

```lua
{
    get_name = ...,
    get_side = function() return "client" end
}
```

---

## Приоритет полей

Если поле существует одновременно в `shared` и в текущей стороне (`server` или `client`), версия из стороны выполнения переопределяет общую.

```lua
function shared.test()
    return "shared"
end

function server.test()
    return "server"
end
```

На сервере результат будет:

```lua
module.test() --> "server"
```

На клиенте:

```lua
module.test() --> "shared"
```
