# Документация модуля Audio [W. I. P.]

Для работы со звуком предоставляется библиотека **audio**.

## Создание и управление звуковыми эффектами

### Основные функции

1. **Воспроизведение 3D-аудиопотока**
```lua
audio.play_stream(name: string, x: number, y: number, z: number, volume: number, pitch: number, [channel: string], [loop: boolean]) -> number, Speaker
```
Параметры:
- `name` - путь к аудиофайлу
- `x, y, z` - координаты источника звука
- `volume` - громкость (0.0–1.0)
- `pitch` - скорость воспроизведения (0.0–1.0)
- `channel` - канал воспроизведения (по умолчанию "regular")
- `loop` - зацикливание звука (по умолчанию false)

Возвращает ID спикера и объект Speaker.

2. **Воспроизведение 2D-аудиопотока**
```lua
audio.play_stream_2d(name: string, volume: number, pitch: number, [channel: string], [loop: boolean]) -> number, Speaker
```
Аналогично `play_stream`, но без позиционирования.

3. **Воспроизведение 3D-звука**
```lua
audio.play_sound(name: string, x: number, y: number, z: number, volume: number, pitch: number, [channel: string], [loop: boolean]) -> number, Speaker
```
Воспроизводит одиночный звук.

4. **Воспроизведение 2D-звука**
```lua
audio.play_sound_2d(name: string, volume: number, pitch: number, [channel: string], [loop: boolean]) -> number, Speaker
```
Аналогично `play_sound`, но без позиционирования.

5. **Подсчет активных спикеров**
```lua
audio.count_speakers() -> number
```
Возвращает количество активных спикеров.

6. **Подсчет активных потоков**
```lua
audio.count_streams() -> number
```
Возвращает количество активных аудиопотоков.

7. **Регистрация продолжительности звука**
```lua
audio.register_duration(name: string, duration: number)
```
Регистрирует продолжительность звука в секундах

## Объект Speaker

Все методы доступны через объект Speaker, возвращаемый функциями воспроизведения.

### Основные методы

1. **Остановка спикера**
```lua
speaker:stop()
```

2. **Приостановка спикера**
```lua
speaker:pause()
```

3. **Возобновление воспроизведения**
```lua
speaker:resume()
```

4. **Проверка зацикливания**
```lua
speaker:is_loop() -> boolean
```

5. **Установка зацикливания**
```lua
speaker:set_loop(loop: boolean)
```

6. **Получение громкости**
```lua
speaker:get_volume() -> number
```

7. **Установка громкости**
```lua
speaker:set_volume(volume: number)
```

8. **Получение скорости звука**
```lua
speaker:get_pitch() -> number
```

9. **Установка скорости звука**
```lua
speaker:set_pitch(pitch: number)
```

10. **Получение текущего времени воспроизведения**
```lua
speaker:get_time() -> number
```

11. **Установка времени воспроизведения**
```lua
speaker:set_time(time: number)
```

12. **Получение позиции спикера в мире**
```lua
speaker:get_position() -> number, number, number
```

13. **Установка позиции спикера в мире**
```lua
speaker:set_position(x: number, y: number, z: number)
```

14. **Получить скорость движения источника звука в мире**
```lua
speaker:get_velocity() -> number, number, number
```

15. **Установить скорость движения источника звука в мире**
```lua
speaker:set_velocity(x: number, y: number, z: number)
```

16. **Получение длительности (техническое ограничение)**
```lua
speaker:get_duration() -> number
```
Возвращает 0 из-за технических ограничений, если продолжительность звука не зарегистрирована.

17. **Получение оставшегося времени до конца воспроизведения звука**
```lua
speaker:get_time_left()
```
Возвращает nil из-за технических ограничений, если продолжительность звука не зарегистрирована.

### Пример использования
```lua
local Speaker = nil

function on_world_open( ... )
    local audio = require "api/api".server.audio

    _, Speaker = audio.play_stream(
        "blocks/door_close",
        0, 10, 0,
        1,
        1,
        nil,
        true
    )
end

function on_world_tick( ... )
    local cur_time = time.uptime()
    if cur_time > 20 and cur_time < 25 then
        Speaker:pause()
        print("Пауза")
    elseif cur_time >= 25 and cur_time < 35 then
        Speaker:resume()
        Speaker:set_volume(0.25)
        print("Возобновление и уменьшение громкости")
    elseif cur_time >= 35 and Speaker then
        Speaker:stop()
        print("Полная остановка")
        Speaker = nil
    end
end
```
