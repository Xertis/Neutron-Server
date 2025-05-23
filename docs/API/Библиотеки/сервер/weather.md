# Документация модуля погоды

Для работы с погодными эффектами предоставляется библиотека **weather**.

## Создание и управление погодными эффектами

### Основные функции

1. **Создание погодного эффекта**
```lua
weather.create(
    x: number, 
    z: number, 
    radius: number, 
    duration: number, 
    on_finished: function, 
    conf: table
) -> WeatherObj
```
Параметры:
- `x`, `z` - координаты центра погодного эффекта
- `radius` - радиус действия эффекта в блоках
- `duration` - продолжительность в секундах (-1 для бесконечного эффекта)
- `on_finished` - функция обратного вызова при завершении эффекта (может быть nil)
- `conf` - таблица с настройками погоды

2. **Получение погоды по ID**
```lua
weather.get(wid: number) -> WeatherObj | nil
```
Возвращает объект погоды или nil, если эффект не найден

3. **Получение погоды по позиции**
```lua
weather.get_by_pos(x: number, z: number) -> table | nil
```
Возвращает сырые данные о погоде в указанных координатах

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
    time = 5  -- время перехода между состояниями
}
```

## Объект WeatherObj

Все методы доступны через созданный объект погоды.

### Основные методы

1. **Удаление погодного эффекта**
```lua
weather_obj:remove()
```

2. **Перемещение центра эффекта**
```lua
weather_obj:move(x: number, z: number)
```

3. **Получение конфигурации**
```lua
weather_obj:get_config() -> table
```
Возвращает таблицу с текущими настройками погоды

4. **Получение ID эффекта**
```lua
weather_obj:get_wid() -> number
```

5. **Изменение радиуса действия**
```lua
weather_obj:set_radius(radius: number)
```

6. **Изменение продолжительности**
```lua
weather_obj:set_duration(duration: number)
```

7. **Проверка активности**
```lua
weather_obj:is_active() -> boolean
```
Возвращает true, если эффект все еще активен

### Пример использования

```lua
-- Создание дождя
local rain = weather.create(0, 0, 25, -1, nil, {
    weather = {
        fall = { ... },
        fog = { ... }
    },
    name = "rain",
    time = 5
})

if rain:is_active() then
    -- Перемещаем дождь
    rain:move(10, 15)
    
    -- Увеличиваем радиус
    rain:set_radius(30)
    
    -- Получаем конфигурацию
    local config = rain:get_config()
    config.fog_opacity = 0.7  -- Меняем параметры тумана
    
    -- Устанавливаем время действия
    rain:set_duration(60)
end

rain:remove()
```