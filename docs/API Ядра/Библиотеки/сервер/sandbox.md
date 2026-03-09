## Игроки

```lua
-- Возвращает таблицу со всеми игроками онлайн.
-- Ключи — identity игроков, значения — объект Player.
api.sandbox.players.get_all() -> Table<Identity: Player>

-- Проверяет, свободен ли никнейм для конкретного identity (если передан).
api.sandbox.players.is_username_available(username: string, [опционально] identity: string) -> boolean

-- Возвращает объект Client для взаимодействия с игроком (отправка пакетов и т.д.).
api.sandbox.players.get_client(player: Player) -> Client

-- Возвращает таблицу игроков в определённом радиусе.
api.sandbox.players.get_in_radius(
    pos: {x, y, z},
    radius: num
) -> Table<Identity: Player>

-- Возвращает объект игрока по аккаунту.
api.sandbox.players.get_player(account: Account) -> Player

-- Возвращает объект игрока по pid.
api.sandbox.players.get_by_pid(pid: number) -> Player

```

## Проверка статуса (Online)

```lua
-- Проверяет, находится ли игрок в сети по его имени пользователя.
api.sandbox.players.by_username.is_online(username: string) -> boolean

-- Проверяет, находится ли игрок в сети по его уникальному identity.
api.sandbox.players.by_identity.is_online(identity: string) -> boolean

```

## Синхронизация игроков

```lua
-- Изменяет состояние игрока (позиция, ротация, читы)
-- и синхронизирует эти данные с клиентом.
api.sandbox.players.sync_states(
    player: Player,
    states: {pos?={x,y,z}, rot?={x,y,z}, cheats?={noclip, flight}}
)

```

## Синхронизация блоков

```lua
-- Отправляет полные данные инвентаря блока на позиции pos указанному клиенту.
api.sandbox.blocks.sync_inventory(
    pos: {x, y, z},
    client: Client
)

-- Синхронизирует конкретный слот инвентаря блока на позиции pos.
api.sandbox.blocks.sync_slot(
    pos: {x, y, z},
    slot: {slot_id: number, item_id: number, item_count: number},
    client: Client
)

```
