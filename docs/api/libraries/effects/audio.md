# audio

> [!NOTE]
> Документация модуля Audio находится в разработке (W.I.P.).

**Содержание**
- [Основные функции](#основные-функции)
- [Объект Speaker](#объект-speaker)
- [Пример использования](#пример-использования)

## Основные функции

```lua
-- Воспроизведение 3D-аудиопотока
audio.play_stream(
    name: string,
    x: number, y: number, z: number,
    volume: number,
    pitch: number,
    [channel: string],
    [loop: boolean]
) -> number, Speaker

-- Воспроизведение 2D-аудиопотока
audio.play_stream_2d(
    name: string,
    volume: number,
    pitch: number,
    [channel: string],
    [loop: boolean]
) -> number, Speaker

-- Воспроизведение 3D-звука
audio.play_sound(
    name: string,
    x: number, y: number, z: number,
    volume: number,
    pitch: number,
    [channel: string],
    [loop: boolean]
) -> number, Speaker

-- Воспроизведение 2D-звука
audio.play_sound_2d(
    name: string,
    volume: number,
    pitch: number,
    [channel: string],
    [loop: boolean]
) -> number, Speaker

-- Подсчёт активных спикеров
audio.count_speakers() -> number

-- Подсчёт активных потоков
audio.count_streams() -> number

-- Регистрация продолжительности звука
audio.register_duration(name: string, duration: number)
```

## Объект Speaker

| Метод | Описание |
|-------|----------|
| `speaker:stop()` | Остановка спикера. |
| `speaker:pause()` | Приостановка. |
| `speaker:resume()` | Возобновление воспроизведения. |
| `speaker:is_loop() -> boolean` | Проверка зацикливания. |
| `speaker:set_loop(loop: boolean)` | Установка зацикливания. |
| `speaker:get_volume() -> number` | Получение громкости. |
| `speaker:set_volume(volume: number)` | Установка громкости. |
| `speaker:get_pitch() -> number` | Получение скорости звука. |
| `speaker:set_pitch(pitch: number)` | Установка скорости звука. |
| `speaker:get_time() -> number` | Текущее время воспроизведения. |
| `speaker:set_time(time: number)` | Установка времени воспроизведения. |
| `speaker:get_position() -> number, number, number` | Позиция в мире. |
| `speaker:set_position(x, y, z)` | Установка позиции. |
| `speaker:get_velocity() -> number, number, number` | Скорость движения источника. |
| `speaker:set_velocity(x, y, z)` | Установка скорости. |
| `speaker:get_duration() -> number` | Возвращает `0`, если продолжительность не зарегистрирована. |
| `speaker:get_time_left()` | Возвращает `nil`, если продолжительность не зарегистрирована. |

## Пример использования

```lua
local Speaker = nil

function on_world_open()
    local audio = require "api/api".server.audio
    _, Speaker = audio.play_stream(
        "blocks/door_close",
        0, 10, 0,
        1, 1,
        nil, true
    )
end

function on_world_tick()
    local cur_time = time.uptime()
    if cur_time > 20 and cur_time < 25 then
        Speaker:pause()
    elseif cur_time >= 25 and cur_time < 35 then
        Speaker:resume()
        Speaker:set_volume(0.25)
    elseif cur_time >= 35 and Speaker then
        Speaker:stop()
        Speaker = nil
    end
end
```
