Система **bson** позволяет сериализовывать  и десериализовывать данные.

1. **Сериализация:**
```lua
api.bson.encode(buffer: DataBuffer, tbl: Table)
```
   - Записывает в **buffer** таблицу **tbl**

2. Десериализация:**
```lua
api.bson.decode(buffer) -> Table
```
   - Читает данные из **buffer** и возвращает прочитанную таблицу **Table**