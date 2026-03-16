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

## Управление инвентарями

### Создание контроллера
```lua
-- Загружает и возвращает контроллер на основе пути к файлу .lua 
-- (или можно передать таблицу с описанными ивентами),
-- который управляет серверной логикой инвентарей
-- похож на файлы логики макетов .xml.lua
api.sandbox.inventories.create_controller(source: string | table) -> InventoryController
```

### Ивенты контроллера
```lua
-- Вызывается при открытии инвентаря игроком
-- x, y, z не передаются, если был открыт виртуальный инвентарь
function on_open(player: Player, invid: int, x: int, y: int, z: int) end

-- Вызывается при закрытии инвентаря игроком
function on_close(player: Player, invid: int)

-- Вызывается при взаимодействии игрока со слотом инвентаря
-- аналог ивента pack:.hudinventoryinteract
function on_update(player: Player, invid: int, slot: int, action: int, mode: int)

-- Вызывается при взаимодействии со слотом через шифт
-- item_id передаётся для тех случаев, когда share происходит с source (бесконечным) слотом
function on_share(player: Player, invid: int, slot: int, item_id: int)
```

### Методы для работы с инвентарями
```lua
-- Устанавливает контроллер для определённого типа контента
-- Если ident это айди блока (число), всем инвентарям этого типа блоков будет установлен этот контроллер
-- Если ident это макет (строка, пр: "pack:craft_table"), всем виртуальным инвентарям с этим макетом будет установлен этот контроллер
api.sandbox.inventories.set_controller(ident: int | string, controller: InventoryController

-- Открывает инвентарь блока переданному игроку
api.sandbox.inventories.open_block(player: Player, pos: vec3)

-- Открывает виртуальный инвентарь переданному игроку
api.sandbox.inventories.open(
	player: Player, 
	layout_path: string,
	-- Не открывать инвентарь игрока
	[опционально] disable_player_inventory: boolean,
	-- Инвентарь, к которому будет привязан UI макет
	[опционально] root_invid: int
)

-- Закрывает открытый инвентарь переданному игроку
api.sandbox.inventories.close(player: Player)

-- Закрывает определённый открытый инвентарь всем игрокам, у которых он открыт
api.sandbox.inventories.echo_close(invid: int)

-- Возвращает invid открытого инвентаря у игрока
api.sandbox.inventories.get_second_inventory(player: Player)
```
## Проверка статуса

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
