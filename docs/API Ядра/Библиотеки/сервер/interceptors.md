# Система `interceptors`

Модуль `interceptors` позволяет добавлять промежуточные обработчики (interceptor) для пакетов — вызываются перед основной обработкой/отправкой.

## Доступные типы пакетов

* `packets.ServerMsg` — пакеты, **отправляемые сервером** (идут клиенту)
* `packets.ClientMsg` — пакеты, **отправляемые клиентом** (приходят на сервер)

> Замечание: для удобства ниже описаны *приёмные* и *отправные* interceptor; между ними нет отличий по сигнатуре и логике — только направление пакета (receive — входящие от клиента; send — исходящие клиенту).

## Добавление interceptor (универсально)

```lua
api.interceptors.receive.add_interceptor(packet_type, interceptor)
api.interceptors.send.add_interceptor(packet_type, interceptor)
```

**Параметры:**

* `packet_type` (string) — тип пакета (`ServerMsg` или `ClientMsg`)
* `interceptor` (function) — функция-обработчик

**Сигнатура interceptor:**

```lua
function(client, original_packet, edited_packet)
```

* `client` — Client, источник/получатель пакета
* `original_packet` — оригинальные данные пакета
* `edited_packet` — данные, изменённые предыдущими обработчиками; именно они будут переданы дальше при успешном прохождении всех interceptor

**Возвращаемое значение:**

* `true` — продолжить обработку / отправку
* `false` / `nil` — остановить (receive: пакет не будет обработан сервером; send: пакет не будет отправлен клиенту)

## Добавление общего обработчика для всех пакетов

```lua
api.interceptors.receive.add_generic_interceptor(interceptor)
api.interceptors.send.add_generic_interceptor(interceptor)
```

Работают как `add_interceptor`, но применяются ко всем типам пакетов (receive — ко всем входящим; send — ко всем исходящим). Поведение возврата такое же: если хоть один общий или специфический send-interceptor вернёт `false`, пакет НЕ будет отправлен клиенту.

## Примеры

Приём (receive):

```lua
interceptors.receive.add_interceptor("ClientMsg", function(client, original, edited)
    if not packet then return false end
    return true
end)
```

Отправка (send) — идентично, но для пакетов, которые сервер шлёт клиенту:

```lua
interceptors.send.add_interceptor("ServerMsg", function(client, original, edited)
    if original.example ~= edited.example then return false end
    return true
end)
```
