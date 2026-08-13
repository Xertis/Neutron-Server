# interceptors

**Содержание**
- [Типы пакетов](#типы-пакетов)
- [Добавление interceptor](#добавление-interceptor)
- [Добавление общего обработчика](#добавление-общего-обработчика)
- [Примеры](#примеры)

## Типы пакетов

| Тип | Описание |
|-----|----------|
| `packets.ServerMsg` | Пакеты, **отправляемые сервером** (идут клиенту). |
| `packets.ClientMsg` | Пакеты, **отправляемые клиентом** (приходят на сервер). |

## Добавление interceptor

```lua
api.interceptors.receive.add_interceptor(packet_type, interceptor)
api.interceptors.send.add_interceptor(packet_type, interceptor)
```

**Параметры:**

| Параметр | Описание |
|----------|----------|
| `packet_type` | Тип пакета (`ServerMsg` или `ClientMsg`). |
| `interceptor` | Функция-обработчик. |

**Сигнатура interceptor:**

```lua
function(client, original_packet, edited_packet)
```

- `client` — Client, источник/получатель пакета.
- `original_packet` — оригинальные данные пакета.
- `edited_packet` — данные, изменённые предыдущими обработчиками.

**Возвращаемое значение:**

- `true` — продолжить обработку/отправку.
- `false` / `nil` — остановить.

## Добавление общего обработчика

```lua
api.interceptors.receive.add_generic_interceptor(interceptor)
api.interceptors.send.add_generic_interceptor(interceptor)
```

Работают как `add_interceptor`, но применяются ко всем типам пакетов.

## Примеры

**Приём (receive):**

```lua
interceptors.receive.add_interceptor("ClientMsg", function(client, original, edited)
    if not packet then return false end
    return true
end)
```

**Отправка (send):**

```lua
interceptors.send.add_interceptor("ServerMsg", function(client, original, edited)
    if original.example ~= edited.example then return false end
    return true
end)
```
