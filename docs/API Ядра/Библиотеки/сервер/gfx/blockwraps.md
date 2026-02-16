# Документация модуля обёрток блоков

Для работы с обёртками блоков предоставляется библиотека **blockwraps**

## Основные функции модуля

### Создание и удаление обёртки

```lua
wraps.wrap(position: vec3, texture: string) -> id, BlockWrap
```
Создаёт обёртку блока в указанной позиции с заданной текстурой. Возвращает ID обёртки и объект `BlockWrap` для управления.

```lua
wraps.unwrap(id: number)
```
Удаляет обёртку блока по её ID.

### Прямой доступ к функциям

Модуль предоставляет прямые аналоги методов объекта `BlockWrap`:

```lua
wraps.set_pos(id: number, position: vec3)
wraps.set_texture(id: number, texture: string)
```

## Объект BlockWrap

Объект, возвращаемый функцией `wrap()`, предоставляет методы для управления обёрткой блока.

### Основные методы

```lua
BlockWrap:unwrap()
```
Удаляет обёртку блока из мира.

```lua
BlockWrap:set_pos(position: vec3)
```
Устанавливает новую позицию обёртки.

```lua
BlockWrap:get_pos() -> vec3
```
Возвращает текущую позицию обёртки.

```lua
BlockWrap:set_texture(texture: string)
```
Устанавливает новую текстуру обёртки.

```lua
BlockWrap:get_texture() -> string
```
Возвращает текущую текстуру обёртки.

## Пример использования

```lua
local wrap = nil

function on_world_open()
    local wraps = require "server:api/api".server.blockwraps

    local id, blockWrap = wraps.wrap({0, 5, 0}, "blocks:sand")
    wrap = blockWrap
end

function on_world_tick()
    if time.uptime() > 20 then
        wrap:set_texture("blocks:ice")
    end
end
```