# weather

**Содержание**
- [Основные функции](#основные-функции)
- [Конфигурация погоды](#конфигурация-погоды)
- [Объект WeatherObj](#объект-weatherobj)
- [Примеры использования](#примеры-использования)

## Основные функции

```lua
-- Создание погодного эффекта
weather.create(region: table, conf: table) -> WeatherObj

-- Получение погоды по ID
weather.get(wid: number) -> WeatherObj | nil

-- Получение погоды по позиции
weather.get_by_pos(x: number, z: number) -> WeatherObj | nil
```

### Параметр `region`

**Тип "point":**

| Поле | Описание |
|------|----------|
| `type = "point"` | Тип эффекта. |
| `x`, `z` | Координаты центра. |
| `radius` | Радиус действия в блоках. |
| `duration` | Продолжительность в секундах (`-1` для бесконечного). |
| `on_finished` | Функция обратного вызова при завершении (может быть `nil`). |

**Тип "heightmap":**

| Поле | Описание |
|------|----------|
| `type = "heightmap"` | Тип эффекта. |
| `heightmap_generator` | `function(x, z, SEED) -> HeightMap` |
| `range` | Диапазон значений высот `{min, max}`. |

> [!IMPORTANT]
> В функцию `heightmap_generator` передаётся специальный сид погоды, который обновляется на основе текущего игрового времени.

## Конфигурация погоды

```lua
{
    weather = {
        fall = {
            texture = "misc/rain",
            max_intensity = 0.5,
            vspeed = 2,
            noise = "ambient/rain",
            min_opacity = 0.8,
            splash = {
                spawn_interval = 0,
                lifetime = 0.2,
                size = {0.2, 0.2, 0.2},
                frames = {
                    "particles:rain_splash_0",
                    "particles:rain_splash_1",
                    "particles:rain_splash_2"
                }
            }
        },
        fog_curve = 0.5,
        fog_opacity = 0.5,
        fog_dencity = 1.7,
        clouds = 0
    },
    name = "rain",
    time = 5
}
```

## Объект WeatherObj

| Метод | Описание | Тип |
|-------|----------|-----|
| `weather_obj:remove()` | Удаление эффекта. | оба |
| `weather_obj:move(x, z)` | Перемещение центра. | point |
| `weather_obj:set_radius(radius)` | Изменение радиуса. | point |
| `weather_obj:set_duration(duration)` | Изменение продолжительности. | point |
| `weather_obj:set_finish_handler(handler)` | Новый обработчик окончания. | point |
| `weather_obj:set_heightmap_generator(gen)` | Установка генератора. | heightmap |
| `weather_obj:set_height_range(min, max)` | Диапазон высот. | heightmap |
| `weather_obj:get_config() -> table` | Текущая конфигурация. | оба |
| `weather_obj:get_wid() -> number` | ID эффекта. | оба |
| `weather_obj:get_type() -> string` | Тип (`"point"` или `"heightmap"`). | оба |
| `weather_obj:is_active() -> boolean` | Активность. | оба |

## Примеры использования

**Point:**

```lua
local rain = weather.create({
    type = "point",
    x = 0, z = 0,
    radius = 25,
    duration = -1,
    on_finished = nil
}, { ... })

if rain:is_active() then
    rain:move(10, 15)
    rain:set_radius(30)
    rain:set_duration(60)
end
rain:remove()
```

**Heightmap:**

```lua
function gen(x, y, SEED)
    local w, h = 32, 32
    local s = 0.2
    local umap = Heightmap(w, h)
    local vmap = Heightmap(w, h)
    umap.noiseSeed = SEED
    vmap.noiseSeed = SEED
    vmap:noise({x+521, y+70}, 0.1*s, 3, 25.8)
    vmap:noise({x+95, y+246}, 0.15*s, 3, 25.8)

    local map = Heightmap(w, h)
    map.noiseSeed = SEED
    map:noise({x, y}, 0.8*s, 4, 0.02)
    map:cellnoise({x, y}, 0.1*s, 3, 0.3, umap, vmap)
    map:add(0.7)
    return map
end

local rain = weather.create({
    type = "heightmap",
    heightmap_generator = gen,
    range = {0.2, 0.8}
}, { ... })

if rain:is_active() then
    rain:set_height_range(0.3, 0.9)
end
rain:remove()
```
