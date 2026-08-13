# particles

**Содержание**
- [Основные функции](#основные-функции)
- [Объект ParticleObj](#объект-particleobj)
- [Пример использования](#пример-использования)

## Основные функции

```lua
-- Создание частицы
particles.emit(
    origin: table | uid,
    count: int,
    preset: table,
    [extension: table]
) -> ParticleObj

-- Получение эмитера по ID
particles.get(pid: int) -> ParticleObj | nil
```

## Объект ParticleObj

| Метод | Описание |
|-------|----------|
| `particle:stop()` | Удаление эмитера частиц. |
| `particle:is_alive() -> boolean` | Состояние эмитера. |
| `particle:get_origin() -> vec3 / uid` | Получение `origin`. |
| `particle:set_origin(origin: vec3 / uid)` | Изменение `origin`. |
| `particle:get_pos() -> vec3` | Позиция эмитера. |

## Пример использования

```lua
local particle = nil

function on_world_open()
    local particles = require "api/api".server.particles
    local x, y, z = 0, 0, 0

    particle = particles.emit({x+0.5, y+0.5, z+0.5}, -1, {
        lifetime = 1.0,
        spawn_interval = 0.0001,
        explosion = {4, 4, 4},
        texture = "blocks:"..block.get_textures(id)[1],
        random_sub_uv = 0.1,
        size = {0.1, 0.1, 0.1},
        spawn_shape = "box",
        spawn_spread = {0.4, 0.4, 0.4}
    })
end

function on_world_tick()
    if time.uptime() > 30 then
        particle:stop()
    end
end
```
