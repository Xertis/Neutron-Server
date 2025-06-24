Система **inventory_data** позволяет компактно сериализовывать и десериализовывать данные инвентарей.

1. **Сериализация:**
```lua
api.inventory_data.serialize(inv: Table<Any>) -> Table<Bytes>
```
   - Возвращает инвентарь в виде массива байт

2. **Десериализация:**
```lua
api.inventory_data.deserialize(bytes: Table<Bytes) -> Table<Any>
```
   - Читает инвентарь из массива байт

### Сигнатура инвентарей
```lua
local inv = {
    {id = 1, count = 10},                -- Предмет в слоте без меты
    {id = 1, count = 1, meta = {...}}    -- Предмет в слоте с метой (мета сериализуется через bson)
}
```