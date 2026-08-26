# players

Контракт секции `players`, которую обязана реализовать оболочка. Доступна через `api.extensions.players`.

**Содержание**
- [Идентификация игрока](#идентификация-игрока)

## Идентификация игрока

```lua
-- Возвращает идентификатор основного игрока
api.extensions.players.get_main_identity() -> string

-- Устанавливает идентификатор основного игрока
-- Вызывается оболочкой на этапе инициализации/авторизации
api.extensions.players.set_main_identity(id: string)

-- Возвращает имя основного игрока
api.extensions.players.get_main_username() -> string

-- Устанавливает имя основного игрока
api.extensions.players.set_main_username(username: string)
```
