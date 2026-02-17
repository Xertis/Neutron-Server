Система **bson** позволяет сериализовывать  и десериализовывать данные.

1. **Сериализация:**
```lua
api.bson.serialize(tbl: Table<Any>) -> Table<Bytes>
```
   - Возвращает **tbl** в виде байт

2. **Десериализация:**
```lua
api.bson.deserialize(bytes: Table<Bytes) -> Table<Any>
```
   - Читает таблицу из массива байт