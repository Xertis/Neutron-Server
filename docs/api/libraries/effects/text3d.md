# text3d

**Содержание**
- [Основные функции](#основные-функции)
- [Объект Text](#объект-text)
- [Пример использования](#пример-использования)

## Основные функции

```lua
-- Создание 3D текста
text3d.show(position: vec3, text: string, preset: table, [extension: table]) -> id, TextObject

-- Получение объекта по id
text3d.get_obj(id) -> TextObject | nil

-- Прямой доступ
text3d.hide(id)
text3d.get_text(id)
text3d.set_text(id, text)
text3d.get_pos(id)
text3d.set_pos(id, position)
text3d.get_axis_x(id)
text3d.get_axis_y(id)
text3d.set_axis_x(id, axis)
text3d.set_axis_y(id, axis)
text3d.set_rotation(id, rotation)
text3d.update_settings(id, preset)
...
```

## Объект Text

| Метод | Описание |
|-------|----------|
| `text:hide()` | Удаляет текст из мира. |
| `text:get_text() -> string` | Текущий текст. |
| `text:set_text(text: string)` | Устанавливает новый текст. |
| `text:get_pos() -> vec3` | Текущая позиция. |
| `text:set_pos(position: vec3)` | Новая позиция. |
| `text:get_axis_x() -> vec3` | Вектор оси X. |
| `text:get_axis_y() -> vec3` | Вектор оси Y. |
| `text:set_axis_x(axis: vec3)` | Установка оси X. |
| `text:set_axis_y(axis: vec3)` | Установка оси Y. |
| `text:set_rotation(rotation: mat4)` | Вращение через матрицу. |
| `text:update_settings(preset: table)` | Обновление настроек отображения. |
| `text:add_blind(player: Player)` | Добавляет игрока в список тех, кто **не** видит текст. |
| `text:remove_blind(player: Player)` | Убирает игрока из списка blind. |
| `text:add_sighted(player: Player)` | Добавляет игрока в список тех, кто **видит** текст. |
| `text:remove_sighted(player: Player)` | Убирает игрока из списка sighted. |
| `text:get_entity() -> int` | Сущность, к которой привязан текст. |
| `text:set_entity(entity: int)` | Установка привязки к сущности. |

> [!NOTE]
> Если список `sighted` пуст, текст может видеть каждый. Позиция, устанавливаемая через `set_pos`, относительна позиции сущности, если текст к ней привязан.

## Пример использования

```lua
local Text = nil

function on_world_open()
    local text3d = require "server:api/api".server.text3d
    local id, text = text3d.show({0,0,0}, "Текстовый текст", {}, {})
    Text = text
end

local timer = 0

function on_world_tick()
    if not Text then return end
    if timer < 20 then
        timer = timer + 1
        return
    end
    timer = 0
    local pos = Text:get_pos()
    Text:set_pos({pos[1], pos[2]+1, pos[3]})
    print(table.tostring(Text:get_pos()))
end
```
