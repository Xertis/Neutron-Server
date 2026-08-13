# blockwraps

**Содержание**
- [Основные функции](#основные-функции)
- [Объект BlockWrap](#объект-blockwrap)
- [Пример использования](#пример-использования)

## Основные функции

```lua
-- Создание обёртки
wraps.wrap(position: vec3, texture: string) -> id, BlockWrap

-- Удаление обёртки
wraps.unwrap(id: number)

-- Прямой доступ
wraps.set_pos(id: number, position: vec3)
wraps.set_texture(id: number, texture: string)
```

## Объект BlockWrap

| Метод | Описание |
|-------|----------|
| `BlockWrap:unwrap()` | Удаляет обёртку из мира. |
| `BlockWrap:set_pos(position: vec3)` | Устанавливает новую позицию. |
| `BlockWrap:get_pos() -> vec3` | Возвращает текущую позицию. |
| `BlockWrap:set_texture(texture: string)` | Устанавливает новую текстуру. |
| `BlockWrap:get_texture() -> string` | Возвращает текущую текстуру. |

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
