# predicted-events

**Содержание**
- [Создание](#создание)
- [Конфиг](#конфиг)
- [Старт события (клиент)](#predictedevent-start-клиент)
- [Объект Instant](#объект-instant)

`PredictedEvent` — обёртка над `Message` для длительных действий с клиентским предсказанием: игрок стартует действие локально, не дожидаясь ответа сервера, сервер валидирует и подтверждает (или отклоняет) запрос, а прогресс синхронизируется с наблюдателями — другими игроками, у которых загружен чанк с позицией действия.

## Создание

```lua
PredictedEvent.new(
    pack: string, 
    event: string, 
    schema: table, 
    config: table
) -> PredictedEvent
```

```lua
local MiningEvent = PredictedEvent.new("mypack", "mining", {
    pos = "Triple<int32, uint8, int32>",
    block = "uint16"
}, {
    -- ...
})
```

- `pack`, `event` — идентификатор пары сообщений, как в `Message.new`; должны совпадать в коде сервера и клиента.
- `schema` — схема данных действия в формате `Message`.
- `config` — набор колбэков; их состав различается для сервера и клиента (см. ниже).

> [!WARNING]
> Схема (`schema`) обязана содержать поле `pos` (координаты `{x, y, z}`) — по нему определяется чанк действия и то, каким клиентам транслировать наблюдение.

## Конфиг

### Сервер

| Поле | Сигнатура | Когда вызывается |
|------|-----------|-------------------|
| `on_start` | `function(client, data) -> boolean` | Клиент начал событие. Возвращаемое значение решает, принять ли действие; также требуется, чтобы чанк `pos` был загружен у клиента. |
| `on_interrupt` | `function(client, instant)` | Клиент прервал событие |
| `on_tick` | `function(client, instant) -> number` | Каждый серверный тик для каждого активного `Instant`. Возвращаемое число — новый прогресс (`0..1`). |
| `on_finish` | `function(client, instant)` | `on_tick` вернул прогресс `>= 1`. |

```lua
local MiningEvent = PredictedEvent.new("mypack", "mining", schema, {
    on_start = function(client, data) return true end,
    on_interrupt = function(client, instant) end,
    on_tick = function(client, instant) return instant:get_progress() + 0.05 end,
    on_finish = function(client, instant) end,
})
```

### Клиент

| Поле | Сигнатура | Когда вызывается |
|------|-----------|-------------------|
| `on_ack_start` | `function(instant)` | Сервер подтвердил действие, либо пришёл пакет о чужом действии. |
| `on_reject` | `function(instant)` | Сервер отклонил запущенное локально действие. |
| `on_progress` | `function(instant)` | Пришёл прогресс для своего или наблюдаемого действия. |
| `on_finish` | `function(instant)` | Действие завершено успешно. |
| `on_interrupt` | `function(instant)` | Действие прервано сервером или другим игроком-наблюдателем. |

```lua
local MiningEvent = PredictedEvent.new("mypack", "mining", schema, {
    on_ack_start = function(instant) end,
    on_reject = function(instant) end,
    on_progress = function(instant) end,
    on_finish = function(instant) end,
    on_interrupt = function(instant) end,
})
```

> [!NOTE]
> Для наблюдаемых (чужих) действий `on_ack_start` вызывается сразу при получении, без промежуточного состояния ожидания — в отличие от собственного действия, запущенного через `:start()`.

## PredictedEvent:start (клиент)

```lua
PredictedEvent:start(data: table) -> Instant
```

```lua
local instant = MiningEvent:start({ pos = player.pos, block = "stone" })
```

Немедленно создаёт локальный `Instant` (`active = false`) и отправляет старт на сервер. `Instant` становится активным только после `on_ack_start`; если сервер отклонит запрос, `Instant` так и останется неактивным и будет вызван `on_reject`.

## Объект Instant

Поля и методы `Instant` различаются на сервере и клиенте — на сервере он привязан к конкретному `client`-инициатору и рассылает синхронизацию наблюдателям, на клиенте это либо своё предсказанное действие, либо снимок чужого.

### Сервер

```lua
Instant.event_id: number
Instant.client: Client
Instant.data: table
Instant.progress: number
Instant.active: boolean

Instant:interrupt()
Instant:finish()
Instant:get_progress() -> number
```

- `interrupt()` / `finish()` — переводят `active` в `false` и рассылают пакеты всем текущим наблюдателям (кроме клиента-инициатора, которому это не нужно).

### Клиент

```lua
Instant.event_id: number | nil
Instant.data: table
Instant.progress: number
Instant.active: boolean

Instant:get_progress() -> number
Instant:interrupt()
```

> [!WARNING]
> `Instant:interrupt()` отправляет "прерывание" только если `instant.active == true`. Для собственного действия это значит — не раньше, чем придёт `on_ack_start`; для наблюдаемого чужого действия `active` не выставляется вовсе.
