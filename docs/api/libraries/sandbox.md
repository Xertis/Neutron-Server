# sandbox

**Содержание**
- [Игроки](#игроки)
- [Управление инвентарями](#управление-инвентарями)
- [Проверка статуса](#проверка-статуса)

## Игроки

```lua
-- Возвращает таблицу со всеми игроками онлайн
api.sandbox.players.get_all() -> table

-- Проверяет, свободен ли никнейм для конкретного identity
api.sandbox.players.is_username_available(username: string, [identity: string]) -> boolean

-- Возвращает объект Client для взаимодействия с игроком
api.sandbox.players.get_client(player: Player) -> Client

-- Возвращает таблицу игроков в определённом радиусе
api.sandbox.players.get_in_radius(pos: {x, y, z}, radius: number) -> table

-- Возвращает объект игрока по аккаунту
api.sandbox.players.get_player(account: Account) -> Player

-- Возвращает объект игрока по pid
api.sandbox.players.get_by_pid(pid: number) -> Player

-- Проверяет, загружен ли чанк у игрока
api.sandbox.players.chunk_is_loaded(player: Player, x: int, z: int) -> boolean

-- Возвращает объект мира, в котором находится игрок
api.sandbox.players.get_world(player: Player) -> World

-- Устанавливает значение игрового правила для игрока
-- На сервере никаких изменений не происходит, ибо игровые правила выполняются на клиенте
api.sandbox.players.set_rule(player: Player, name: string, value: boolean)
```

## Управление инвентарями

### Создание контроллера

```lua
api.sandbox.inventories.create_controller(source: string | table) -> InventoryController
```

Загружает и возвращает контроллер на основе пути к файлу `.lua` (или таблицы с описанными ивентами), который управляет серверной логикой инвентарей.

### Ивенты контроллера

```lua
-- Вызывается при открытии инвентаря игроком
-- x, y, z не передаются, если был открыт виртуальный инвентарь
function on_open(player: Player, invid: int, x: int, y: int, z: int) end

-- Вызывается при закрытии инвентаря игроком
function on_close(player: Player, invid: int) end

-- Вызывается при взаимодействии игрока со слотом инвентаря
-- аналог ивента pack:.hudinventoryinteract
function on_update(player: Player, invid: int, slot: int, action: int, mode: int) end

-- Вызывается при взаимодействии со слотом через шифт
-- item_id передаётся для случаев, когда share происходит с source (бесконечным) слотом
function on_share(player: Player, invid: int, slot: int, item_id: int) end
```

### Методы для работы с инвентарями

```lua
-- Устанавливает контроллер для определённого типа контента
-- ident: число (айди блока) или строка (макет, например "pack:craft_table")
api.sandbox.inventories.set_controller(ident: int | string, controller: InventoryController)

-- Открывает инвентарь блока переданному игроку
api.sandbox.inventories.open_block(player: Player, pos: vec3)

-- Открывает виртуальный инвентарь переданному игроку
api.sandbox.inventories.open(
    player: Player,
    layout_path: string,
    [disable_player_inventory: boolean],
    [root_invid: int]
)

-- Закрывает открытый инвентарь переданному игроку
api.sandbox.inventories.close(player: Player)

-- Закрывает определённый инвентарь всем игрокам, у которых он открыт
api.sandbox.inventories.echo_close(invid: int)

-- Возвращает invid открытого инвентаря у игрока
api.sandbox.inventories.get_second_inventory(player: Player) -> int
```

## Проверка статуса

```lua
-- Проверяет, находится ли игрок в сети по имени пользователя
api.sandbox.players.by_username.is_online(username: string) -> boolean

-- Проверяет, находится ли игрок в сети по identity
api.sandbox.players.by_identity.is_online(identity: string) -> boolean
```
