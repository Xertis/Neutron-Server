Система **sandbox** даёт возможность управлять игроками

1. **Получение всех игроков в онлайне:**
```lua
api.sandbox.players.get_all() -> Table<Username: Player>
```
   - Возвращает таблицу со всеми игроками онлайн. Где ключи - ники игроков, а значения - их объект Player

2. **Получение игроков в определённом радиусе**
```lua
api.sandbox.players.get_in_radius(pos: {x=x, y=y, z=z}, radius: num) -> Table<Username: Player>
```
   - Возвращает таблицу игроков в определённом радиусе

3. **Получение игрока по аккаунту**
```lua
api.sandbox.players.get_player(account: Account) -> Player
```
   - Возвращает класс игрока по аккаунту

4. **Получение игрока по аккаунту**
```lua
api.sandbox.players.set_pos(player: Player, pos: {x=x, y=y, z=z})
```
   - Устанавливает позицию игрока на сервере и синхронизирует её между клиентами
