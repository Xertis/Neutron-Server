# Система `middlewares`

Модуль `middlewares` позволяет добавлять промежуточные обработчики (middleware) для пакетов — вызываются перед основной обработкой/отправкой.

## Доступные типы пакетов

* `packets.ServerMsg` — пакеты, **отправляемые сервером** (идут клиенту)
* `packets.ClientMsg` — пакеты, **отправляемые клиентом** (приходят на сервер)

> Замечание: для удобства ниже описаны *приёмные* и *отправные* middleware; между ними нет отличий по сигнатуре и логике — только направление пакета (receive — входящие от клиента; send — исходящие клиенту).

## Добавление middleware (универсально)

```lua
api.middlewares.receive.add_middleware(packet_type, middleware)
api.middlewares.send.add_middleware(packet_type, middleware)
```

**Параметры:**

* `packet_type` (string) — тип пакета (`ServerMsg` или `ClientMsg`)
* `middleware` (function) — функция-обработчик

**Сигнатура middleware:**

```lua
function(client, original_packet, edited_packet)
```

* `client` — Client, источник/получатель пакета
* `original_packet` — оригинальные данные пакета
* `edited_packet` — данные, изменённые предыдущими обработчиками; именно они будут переданы дальше при успешном прохождении всех middleware

**Возвращаемое значение:**

* `true` — продолжить обработку / отправку
* `false` / `nil` — остановить (receive: пакет не будет обработан сервером; send: пакет не будет отправлен клиенту)

## Добавление общего обработчика для всех пакетов

```lua
api.middlewares.receive.add_general_middleware(middleware)
api.middlewares.send.add_generic_middleware(middleware)
```

Работают как `add_middleware`, но применяются ко всем типам пакетов (receive — ко всем входящим; send — ко всем исходящим). Поведение возврата такое же: если хоть один общий или специфический send-middleware вернёт `false`, пакет НЕ будет отправлен клиенту.

## Примеры

Приём (receive):

```lua
middlewares.receive.add_middleware("ClientMsg", function(client, original, edited)
    if not packet then return false end
    return true
end)
```

Отправка (send) — идентично, но для пакетов, которые сервер шлёт клиенту:

```lua
middlewares.send.add_middleware("ServerMsg", function(client, original, edited)
    if original.example ~= edited.example then return false end
    return true
end)
```
