1. **Синхронизация инвентарей блоков**
```lua
api.sandbox.blocks.sync_inventory(pos: {x=0,y=0,z=0})
```
   - Отправляет данные инвентаря с клиента на сервер
---
2. **Синхронизация слотов блоков**
```lua
api.sandbox.blocks.sync_slot(pos: {x=0,y=0,z=0}, slot: {slot_id=0, item_id=0, item_count=0})
```
   - Отправляет данные слота из инвентаря блока на позиции pos серверу