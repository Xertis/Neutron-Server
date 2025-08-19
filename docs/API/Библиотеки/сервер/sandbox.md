Система **sandbox** даёт возможность управлять игроками

1. **Получение всех игроков в онлайне:**
```lua
api.sandbox.players.get_all() -> Table<Username: Player>
```
   - Возвращает таблицу со всеми игроками онлайн. Где ключи - ники игроков, а значения - их объект Player
---
2. **Получение игроков в определённом радиусе**
```lua
api.sandbox.players.get_in_radius(pos: {x=x, y=y, z=z}, radius: num) -> Table<Username: Player>
```
   - Возвращает таблицу игроков в определённом радиусе

---
3. **Получение игрока по аккаунту**
```lua
api.sandbox.players.get_player(account: Account) -> Player
```
   - Возвращает объект игрока по аккаунту

---
4. **Получение объекта игрока по pid**
```lua
api.sandbox.players.get_by_pid(pid: number) -> Player
```
   - Возвращает объект игрока по **pid**

---
5. **Синхронизация игрока**
```lua
api.sandbox.players.sync_states(player: Player, states: {pos={...}, rot={...}, cheats={...}})
```
   - Изменяет игрока в соответствии с таблицой **states** и принудительно отправляет эти данные на клиент
   - Таблица **states** может содержать частичные данные (может отсутствовать pos/rot/cheats)

   - **Сигнатура States**
   ```lua
   local states = {
      pos = {x = 0, y = 0, z = 0},
      rot = {yaw = 0, pitch = 0},
      cheats = {noclip = false, flight = false}
   }
   ```
---
5. **Синхронизация инвентарей блоков**
```lua
api.sandbox.blocks.sync_inventory(pos: {x=0,y=0,z=0}, client: Client)
```
   - Отправляет данные инвентаря с сервера на клиент
---
6. **Синхронизация слотов блоков**
```lua
api.sandbox.blocks.sync_slot(pos: {x=0,y=0,z=0}, slot: {slot_id=0, item_id=0, item_count=0}, client: Client)
```
   - Отправляет данные слота из инвентаря блока на позиции pos клиенту
