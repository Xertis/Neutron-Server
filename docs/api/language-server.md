# Языковой сервер

- Языковой сервер позволяет добавить подсветку типов нейтрона
- За аннотацию спасибо Коте, файл находится в его [репозитории](https://github.com/kotisoff/NotUtils/blob/main/modules/types/neutron.lua). Так же там можно найти аннотацию для самого VoxelCore

### Пример использования
```lua
function on_world_open()
    ---@type neutron.server
    local api = require(string.format("%s:api/%s/api", m.pack_id, m.api_references.Neutron.latest))[m.side]
end
```
