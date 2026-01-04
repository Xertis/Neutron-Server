## Содержание

* [Игроки](#игроки)
* [Синхронизация игроков](#синхронизация-игроков)
* [Синхронизация блоков](#синхронизация-блоков)

>[!IMPORTANT]
> Все стандартные движковые методы player работают на сервере и сихнронизируются с клиентами

## Игроки

```lua
-- Возвращает таблицу со всеми игроками онлайн.
-- Ключи — identity игроков, значения — объект Player.
api.sandbox.players.get_all() -> Table<Identity: Player>


-- Возвращает таблицу игроков в определённом радиусе.
api.sandbox.players.get_in_radius(
    pos: {x=x, y=y, z=z},
    radius: num
) -> Table<Identity: Player>


-- Возвращает объект игрока по аккаунту.
api.sandbox.players.get_player(account: Account) -> Player


-- Возвращает объект игрока по pid.
api.sandbox.players.get_by_pid(pid: number) -> Player
```

## Синхронизация игроков

```lua
-- Изменяет игрока в соответствии с таблицой states
-- и принудительно отправляет эти данные на клиент.
-- Таблица states может содержать частичные данные
-- (pos / rot / cheats могут отсутствовать).
api.sandbox.players.sync_states(
    player: Player,
    states: {pos={...}, rot={...}, cheats={...}}
)


-- Сигнатура таблицы states:
-- {
--    pos = {x = 0, y = 0, z = 0},
--    rot = {x = 0, y = 0, z = 0},
--    cheats = {noclip = false, flight = false}
-- }
```

## Синхронизация блоков

```lua
-- Отправляет данные инвентаря блока с сервера на клиент.
api.sandbox.blocks.sync_inventory(
    pos: {x=0,y=0,z=0},
    client: Client
)


-- Отправляет данные слота инвентаря блока на позиции pos клиенту.
api.sandbox.blocks.sync_slot(
    pos: {x=0,y=0,z=0},
    slot: {slot_id=0, item_id=0, item_count=0},
    client: Client
)
```
