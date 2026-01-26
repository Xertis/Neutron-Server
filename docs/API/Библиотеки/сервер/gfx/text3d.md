# Документация модуля 3D текста

Для работы с 3д текстом предоставляется библиотека text3d

## Основные функции модуля

### Создание и удаление текста

```lua
text3d.show(position: vec3, text: string, preset: table, [extension: table]) -> id, TextObject
```
Создаёт 3D текст в указанной позиции с заданными параметрами. Возвращает ID текста и объект для управления.

Параметры `preset` и `extension` содержат настройки отображения (см. документацию движка).

### Прямой доступ к функциям

Модуль также предоставляет прямые аналоги всех методов объекта Text:

```lua
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
```

## Объект Text

Объект, возвращаемый функцией `show()`, предоставляет методы для управления текстом.

## Получение объекта по id
```lua
text3d.get_obj(id) -> TextObject
```

### Основные методы

```lua
text:hide()
```
Удаляет текст из мира.

```lua
text:get_text() -> string
```
Возвращает текущий текст.

```lua
text:set_text(text: string)
```
Устанавливает новый текст.

```lua
text:get_pos() -> vec3
```
Возвращает текущую позицию текста.

```lua
text:set_pos(position: vec3)
```
Устанавливает новую позицию текста.

```lua
text:get_axis_x() -> vec3
text:get_axis_y() -> vec3
```
Возвращают вектора осей текста.

```lua
text:set_axis_x(axis: vec3)
text:set_axis_y(axis: vec3)
```
Устанавливают вектора осей текста.

```lua
text:set_rotation(rotation: mat4)
```
Устанавливает вращение текста через матрицу.

```lua
text:update_settings(preset: table)
```
Обновляет настройки отображения текста.
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
    if not Text then
        return
    end

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