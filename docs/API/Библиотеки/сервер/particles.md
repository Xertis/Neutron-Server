# Документация модуля частиц

Для работы с частицами предоставляется библиотека **particles**

## Создание и управление частицами

### Основные функции

1. **Создание частицы**
```lua
particles.emit(
	origin: table | uid, 
	count: int, 
	preset: table, 
	[опционально] extension: table
) -> ParticleObj
```
Параметры:
-	Передаваемые параметры полностью соответствуют тем, что передаются в [gfx.particles.emit](https://github.com/MihailRis/voxelcore/blob/main/doc/ru/particles.md) из стандартной библиотеки движка

2. **Получение эммитера частиц по ID**
```lua
weather.get(pid: int) -> ParticlerObj | nil
```
Возвращает объект партиклов или nil, если эффект не найден.

## Объект ParticleObj

Все методы доступны через созданный объект погоды.

### Основные методы

1. **Удаление эммитера частиц**
```lua
particle:stop()
```

2. **Получение состояния эммитера**
```lua
particle:is_alive() -> Boolean
```

3. **Получение `origin` эммитера**
```lua
particle:get_origin() -> table | uid
```

4. **Изменение `origin` эммитера**
```lua
particle:set_origin(origin: table | uid)
```

5. **Получение позиции эммитера**
```lua
particle:get_pos() -> table
```

6. **Получение позиции эммитера**
```lua
particle:get_pos() -> table
```

### Пример использования

```lua
local particle = nil

function on_world_open()
    local particles = require "api/api".server.particles
    local x, y, z = 0, 0, 0

    particle = particles.emit({x+0.5, y+0.5, z+0.5}, -1, {
    lifetime=1.0,
    spawn_interval=0.0001,
    explosion={4, 4, 4},
    texture="blocks:"..block.get_textures(id)[1],
    random_sub_uv=0.1,
    size={0.1, 0.1, 0.1},
    spawn_shape="box",
    spawn_spread={0.4, 0.4, 0.4}
}) -- Спавнит бесконечные частицы
end

function on_world_tick( ... )
    if time.uptime() > 30 then
        particle:stop() -- Через 30 сек удаляет частицы
    end
end