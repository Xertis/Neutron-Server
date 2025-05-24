# Документация модуля погоды

Для работы с погодными эффектами предоставляется библиотека **weather**, поддерживающая два типа погодных эффектов: "point" и "heightmap".

## Создание и управление погодными эффектами

### Основные функции

1. **Создание погодного эффекта**
```lua
weather.create(region: table, conf: table) -> WeatherObj
```
Параметры:
- `region` - таблица, описывающая регион действия эффекта:
  - Для типа "point":
    - `type = "point"`
    - `x: number`, `z: number` - координаты центра эффекта
    - `radius: number` - радиус действия в блоках
    - `duration: number` - продолжительность в секундах (-1 для бесконечного эффекта)
    - `on_finished: function` - функция обратного вызова при завершении эффекта (может быть nil)
  - Для типа "heightmap":
    - `type = "heightmap"`
    - `heightmap_generator: function (x, z, SEED) -> HeightMap` - функция генерации карты высот
    - `range: table` - диапазон значений высот `{min, max}`
- `conf` - таблица с настройками погоды:
  - `weather: table` - настройки погодного эффекта
  - `name: string` - имя эффекта (опционально)
  - `time: number` - время перехода между состояниями

>[!IMPORTANT]
> В функцию `heightmap_generator` передаётся специальный сид погоды, который обновляется на основе текущего игрового времени, обеспечивая изменчивость погодных эффектов

2. **Получение погоды по ID**
```lua
weather.get(wid: number) -> WeatherObj | nil
```
Возвращает объект погоды или nil, если эффект не найден.

3. **Получение погоды по позиции**
```lua
weather.get_by_pos(x: number, z: number) -> WeatherObj | nil
```
Возвращает объект погоды на указанных координатах или nil.

### Конфигурация погоды (параметр `conf`)

Пример конфигурации дождя:
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

Все методы доступны через созданный объект погоды.

### Основные методы

1. **Удаление погодного эффекта**
```lua
weather_obj:remove()
```

2. **Перемещение центра эффекта (только для типа "point")**
```lua
weather_obj:move(x: number, z: number)
```

3. **Изменение радиуса действия (только для типа "point")**
```lua
weather_obj:set_radius(radius: number)
```

4. **Изменение продолжительности (только для типа "point")**
```lua
weather_obj:set_duration(duration: number)
```

5. **Изменение обработчика окончания погоды (только для типа "point")**
```lua
weather_obj:set_finish_handler(handler: function)
```

6. **Установка генератора карты высот (только для типа "heightmap")**
```lua
weather_obj:set_heightmap_generator(heightmap_generator: function)
```

7. **Установка диапазона высот (только для типа "heightmap")**
```lua
weather_obj:set_height_range(min: number, max: number)
```

8. **Получение конфигурации**
```lua
weather_obj:get_config() -> table
```
Возвращает таблицу с текущими настройками погоды.

9. **Получение ID эффекта**
```lua
weather_obj:get_wid() -> number
```

10. **Получение типа эффекта**
```lua
weather_obj:get_type() -> string
```
Возвращает тип эффекта ("point" или "heightmap").

11. **Проверка активности**
```lua
weather_obj:is_active() -> boolean
```
Возвращает true, если эффект активен.

### Пример использования

```lua
-- Создание дождя типа "point"
local rain = weather.create({
    type = "point",
    x = 0,
    z = 0,
    radius = 25,
    duration = -1,
    on_finished = nil
}, {
    weather = {
        fall = {
            texture = "misc/rain",
            max_intensity = 0.5,
            vspeed = 2,
            noise = "ambient/rain",
            min_opacity = 0.8
        },
        fog_curve = 0.5,
        fog_opacity = 0.5,
        fog_dencity = 1.7
    },
    name = "rain",
    time = 5
})

if rain:is_active() then
    print("Тип эффекта: " .. rain:get_type())
    rain:move(10, 15)
    rain:set_radius(30)
    rain:set_duration(60)
    
    local config = rain:get_config()
    config.fog_opacity = 0.7
end

rain:remove()
```

```lua
-- Создание дождя типа "heightmap"

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
    heightmap_generator = gen end,
    range = {0.2, 0.8}
}, {
    weather = {
        fall = {
            texture = "misc/rain",
            max_intensity = 0.5,
            vspeed = 2,
            noise = "ambient/rain",
            min_opacity = 0.8
        },
        fog_curve = 0.5,
        fog_opacity = 0.5,
        fog_dencity = 1.7
    },
    name = "rain",
    time = 5
})

if rain:is_active() then
    rain:set_height_range(0.3, 0.9)
    rain:set_heightmap_generator(gen)
end

rain:remove()
```