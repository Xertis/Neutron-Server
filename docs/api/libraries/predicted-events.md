# predicted-events

**Содержание**
- [Создание](#создание)
- [Конфиг](#конфиг)
- [Старт события (клиент)](#predictedevent-start-клиент)
- [Объект Instance](#объект-instance)

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
| `on_interrupt` | `function(client, instance)` | Клиент прервал событие |
| `on_tick` | `function(client, instance) -> number` | Каждый серверный тик для каждого активного `Instance`. Возвращаемое число — новый прогресс (`0..1`). |
| `on_finish` | `function(client, instance)` | `on_tick` вернул прогресс `>= 1`. |

```lua
local MiningEvent = PredictedEvent.new("mypack", "mining", schema, {
    on_start = function(client, data) return true end,
    on_interrupt = function(client, instance) end,
    on_tick = function(client, instance) return instance:get_progress() + 0.05 end,
    on_finish = function(client, instance) end,
})
```

### Клиент

| Поле | Сигнатура | Когда вызывается |
|------|-----------|-------------------|
| `on_ack_start` | `function(instance)` | Сервер подтвердил действие, либо пришёл пакет о чужом действии. |
| `on_reject` | `function(instance)` | Сервер отклонил запущенное локально действие. |
| `on_progress` | `function(instance)` | Пришёл прогресс для своего или наблюдаемого действия. |
| `on_finish` | `function(instance)` | Действие завершено успешно. |
| `on_interrupt` | `function(instance)` | Действие прервано сервером или игроком-владельцем действия (в случае, если действие наблюдаемое). |

```lua
local MiningEvent = PredictedEvent.new("mypack", "mining", schema, {
    on_ack_start = function(instance) end,
    on_reject = function(instance) end,
    on_progress = function(instance) end,
    on_finish = function(instance) end,
    on_interrupt = function(instance) end,
})
```

> [!NOTE]
> Для наблюдаемых (чужих) действий `on_ack_start` вызывается сразу при получении, без промежуточного состояния ожидания — в отличие от собственного действия, запущенного через `:start()`.

## PredictedEvent:start (клиент)

```lua
PredictedEvent:start(data: table) -> Instance
```

```lua
local instance = MiningEvent:start({ pos = player.pos, block = "stone" })
```

Немедленно создаёт локальный `Instance` (`active = false`) и отправляет старт на сервер. `Instance` становится активным только после `on_ack_start`; если сервер отклонит запрос, `Instance` так и останется неактивным и будет вызван `on_reject`.

## Объект Instance

Поля и методы `Instance` различаются на сервере и клиенте — на сервере он привязан к конкретному `client`-инициатору и рассылает синхронизацию наблюдателям, на клиенте это либо своё предсказанное действие, либо снимок чужого.

### Сервер

```lua
Instance.event_id: number
Instance.client: Client
Instance.data: table
Instance.start_time: number
Instance.progress: number
Instance.active: boolean

Instance:interrupt()              -- Прерывает действие
Instance:get_progress() -> number -- Возвращает прогресс
Instance:get_elapsed() -> number  -- Возвращает прошедшее время с начала выполнения действия 
```

### Клиент

```lua
Instance.instance_id: number       -- Существует только на клиенте, нужен для унификации идентификации инстантов
Instance.event_id: number | nil
Instance.data: table
Instance.start_time: number
Instance.progress: number
Instance.active: boolean

Instance:interrupt()              -- Прерывает действие
Instance:get_progress() -> number -- Возвращает прогресс
Instance:get_elapsed() -> number  -- Возвращает прошедшее время с начала выполнения действия 
```

> [!WARNING]
> `Instance:interrupt()` отправляет "прерывание" только если `instance.active == true`. Для собственного действия это значит — не раньше, чем придёт `on_ack_start`; для наблюдаемого чужого действия `active` не выставляется вовсе.
