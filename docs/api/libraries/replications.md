# replications

**Содержание**
- [Сервер](#сервер)
  - [Создание репликатора](#создание-репликатора)
  - [Схема репликатора](#схема-репликатора)
  - [Публичная реплика](#публичная-реплика)
  - [Приватная реплика](#приватная-реплика)
  - [Удаление реплики](#удаление-реплики)
- [Клиент](#клиент)
  - [Создание слушателя](#создание-слушателя)
  - [Удаление слушателя](#удаление-слушателя)

> [!WARNING]
> Перед чтением клиентской части рекомендуется ознакомиться с серверной документацией `api.replications`.

---

## Сервер

`Replication` — обёртка над `api.messages`, которая берёт на себя синхронизацию состояния таблиц между сервером и клиентом. Вместо того чтобы вручную отправлять `Message:tell`/`Message:echo` при каждом изменении данных, репликатор сам считает разницу между текущим и предыдущим состоянием таблицы и отправляет только изменившиеся поля.

### Создание репликатора

```lua
Replication.new(pack: string, event: string, schema: table) -> Replicator
```

```lua
local PosReplication = Replication.new("mypack", "pos_sync", {
    x = "float32",
    y = "float32",
    z = "float32"
})
```

- `pack` — имя пака, внутри которого репликатор.
- `event` — имя ивента, который будет использоваться репликатором.

> [!WARNING]
> `pack` и `event` **должны быть одинаковыми в коде сервера и клиента**.

### Схема репликатора

Схема описывается так же, как схема обычного сообщения — таблица `{ ключ = тип }` с поддержкой вложенных таблиц:

```lua
local EntityReplication = Replication.new("mypack", "entity_sync", {
    pos = { x = "float32", y = "float32", z = "float32" },
    hp = "uint16"
})
```

> [!WARNING]
> Схема репликатора **не может содержать тип `Nilable`** — `Replication.new` выбросит ошибку, если найдёт его на любом уровне вложенности. Это ограничение связано с тем, что под капотом каждое поле схемы автоматически оборачивается в `Nilable`.

### Публичная реплика

```lua
Replicator:create_public_replica(
    id: int,
    initial_value: table,
    need_send: function(client, dirty): boolean?
) -> table
```

```lua
local replica = PosReplicator:create_public_replica(1, { x = 0, y = 0, z = 0 })
replica.x = 10.5  -- изменение будет подхвачено автоматически и разослано всем
```

Публичная реплика по умолчанию рассылается всем подключённым клиентам.

Если передан `need_send`, рассылка происходит индивидуально для каждого клиента:

```lua
local replica = PosReplication:create_public_replica(1, { x = 0, y = 0, z = 0 },
    function(client, dirty)
        return is_in_view_distance(client, replica)
    end)
```

### Приватная реплика

```lua
Replicator:create_private_replica(id: int, initial_value: table, client: Client) -> table
```

```lua
local inventory = InventoryReplication:create_private_replica(1, { slots = {} }, client)
```

Приватная реплика всегда отправляется только одному, заранее заданному `client`.

### Удаление реплики

```lua
Replicator:remove_replica(id: int)
```

Прекращает отслеживание изменений и удаляет реплику с указанным `id`.

---

## Клиент

### Создание слушателя

На клиенте репликатор не хранит исходные данные сам — вместо этого вы регистрируете *слушателя*, таблица которого автоматически обновляется при получении diff с соответствующим `id`.

```lua
Replicator:create_listener(id: int, initial_value: table, on_recv: function(dirty): boolean?) -> table
```

```lua
local pos = PosReplicator:create_listener(1, { x = 0, y = 0, z = 0 })
print(pos.x, pos.y, pos.z) -- значения обновляются сами при получении новых данных
```

`id` должен совпадать с `id`, который использовался при создании реплики на сервере.

Если передан `on_recv`, он вызывается перед применением входящего diff. Если `on_recv` возвращает `false`, diff не применяется:

```lua
local pos = PosReplication:create_listener(1, { x = 0, y = 0, z = 0 },
    function(dirty)
        if dirty.x then
            on_position_changed(dirty.x)
        end
        return true
    end)
```

> [!WARNING]
> Если diff пришёл с `id`, для которого не зарегистрирован слушатель, репликатор пишет предупреждение в лог и игнорирует данные.

### Удаление слушателя

```lua
Replicator:remove_replica(id: int)
```

Удаляет слушателя — таблица, возвращённая `create_listener`, больше не обновляется.
