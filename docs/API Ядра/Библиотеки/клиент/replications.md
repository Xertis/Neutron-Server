# Replication

**Содержание**
* [Создание слушателя](#создание-слушателя)
* [Удаление слушателя](#удаление-слушателя)

>[!WARNING]
> Перед чтением документации к клиентской части **api.replication**,
рекомендуется прочитать серверную часть.

## Создание слушателя

На клиенте репликатор не хранит исходные данные сам — вместо этого вы
регистрируете *слушателя*, таблица которого автоматически обновляется
при получении diff с соответствующим `id`.

```lua
-- Replicator:create_listener(id: int, initial_value: table, on_recv: function(dirty): boolean?) -> table
local pos = PosReplicator:create_listener(1, { x = 0, y = 0, z = 0 })

print(pos.x, pos.y, pos.z) -- значения обновляются сами при получении новых данных
```

`id` должен совпадать с `id`, который использовался при создании реплики на
сервере — по нему репликатор сопоставляет входящий diff с нужным слушателем.

Если передан `on_recv`, он вызывается перед применением входящего diff с
самим diff (`dirty`) в качестве аргумента. Если `on_recv` возвращает `false`,
diff не применяется к таблице слушателя

```lua
local pos = PosReplication:create_listener(1, { x = 0, y = 0, z = 0 },
    function(dirty)
        if dirty.x then
            on_position_changed(dirty.x)
        end
        return true
    end)
```

>[!WARNING]
> Если diff пришёл с `id`, для которого не зарегистрирован слушатель,
репликатор пишет предупреждение в лог и игнорирует данные.

## Удаление слушателя

```lua
-- Replicator:remove_replica(id: int)
PosReplication:remove_replica(1)
```

Удаляет слушателя — таблица, возвращённая `create_listener`, больше не
обновляется.
