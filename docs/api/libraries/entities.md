# entities

**Содержание**
- [Сервер](#сервер)
  - [Регистрация сущности](#регистрация-сущности)
  - [Структура config](#структура-config)
  - [Вспомогательные функции](#вспомогательные-функции)
  - [Доступные типы](#доступные-типы)
  - [Важные примечания](#важные-примечания)
- [Клиент](#клиент)
  - [Указание обработчика](#указание-обработчика)
  - [Десинхронные сущности](#десинхронные-сущности)

> [!WARNING]
> Перед чтением клиентской части рекомендуется ознакомиться с серверной документацией `api.entities`.

---

## Сервер

Модуль `api.entities` обеспечивает управление сущностями (мобами) на сервере, включая регистрацию, синхронизацию данных и обработку событий спавна/деспавна.

### Регистрация сущности

```lua
entities.register(entity_name, config, spawn_handler)
```

**Параметры:**

| Параметр | Тип | Описание |
|----------|-----|----------|
| `entity_name` | `string` | Имя типа сущности (например, `"example:zombie"`). |
| `config` | `table` | Конфигурация полей сущности. |
| `spawn_handler` | `function(name, args, client)` | Вызывается, когда клиент пытается заспавнить зарегистрированную сущность. |

### Структура config

```lua
{
    on_client_spawn = function(player, uid)
        -- Вызывается при первом появлении сущности на клиенте
        -- Принимает объект игрока и uid сущности
        -- Возвращает таблицу аргументов, которая будет отправлена на клиент
        return { ... }
    end,

    on_client_despawn = function(player, uid)
        -- Вызывается при удалении сущности на клиенте
    end,

    standard_fields = {
        tsf_pos = {
            maximum_deviation = number,
            evaluate_deviation = function(dist, cur_val, client_val)
            end
        }
        -- Другие поля...
    },

    custom_fields = {
        hp = {
            maximum_deviation = number,
            evaluate_deviation = function(dist, cur_val, client_val),
            provider = function(uid, field_name)
            end
        }
    },

    textures = {
        key1 = {
            maximum_deviation = number,
            evaluate_deviation = function(dist, cur_val, client_val),
            [optional] provider = function(uid, field_name)
        }
    },

    models = {
        [index] = {
            maximum_deviation = number,
            evaluate_deviation = function(dist, cur_val, client_val),
            [optional] provider = function(uid, field_name)
        }
    },

    matrix = {
        [index] = {
            maximum_deviation = number,
            evaluate_deviation = function(dist, cur_val, client_val),
            [optional] provider = function(uid, field_name)
        }
    },

    components = {
        component = {
            maximum_deviation = number,
            evaluate_deviation = function(dist, cur_val, client_val),
            provider = function(uid, field_name) -- всегда bool
            -- Если provider вернёт true, компонент включится у клиента, если false — выключится
        }
    }
}
```

| Поле | Описание |
|------|----------|
| `maximum_deviation` | Максимальное отклонение между значениями поля на сервере и клиенте. |
| `provider` | Функция, которая вызывается для получения значения поля. |
| `evaluate_deviation` | Функция, вычисляющая отклонение на основе расстояния до игрока, действительного значения и значения на клиенте. |

> [!NOTE]
> В связи с тем, что `entity.skeleton` по умолчанию не доступен в headless-режиме, поля из **textures**, **models**, **matrix** имеют альтернативный способ получения значений из **provider**.

### Вспомогательные функции

```lua
-- Возвращает math.huge, если значения на клиенте и на сервере НЕ равны, иначе 0.
-- Для таблиц сравнение идёт через глубокое сравнение (table.deep_equals).
entities.eval.NotEquals

-- Предназначена для векторных полей (vec3/vec2, массивы чисел).
-- Возвращает math.huge, если хотя бы одна компонента отличается больше чем на 0.001.
entities.eval.VectorNotEquals

-- Всегда возвращает math.huge
entities.eval.Always

-- Всегда возвращает 0
entities.eval.Never
```

> [!TIP]
> Для полей типа vec3 (`tsf_pos`, `body_size` и т.п.) предпочтительнее использовать `VectorNotEquals`, а не `NotEquals`: она устойчива к погрешностям с плавающей точкой.

### Доступные типы

```lua
entities.types = {
    Custom = "custom_fields",
    Standard = "standard_fields",
    Models = "models",
    Matrix = "matrix",
    Textures = "textures",
    Components = "components"
}
```

`entities.types` — перечисление ключей секций конфига. Это справочная таблица для внешнего кода, позволяющая обращаться к секциям через `entities.types.Matrix` вместо строкового литерала `"matrix"`.

### Важные примечания

1. Данные моба не будут отправляться клиентам, если моб находится вне зоны прогрузки чанков.
2. Если данные сущности переданы на клиент, но сущность на клиенте не создана, она автоматически будет создана на нулевых координатах.
3. Спавн незарегистрированной сущности не приводит к ошибке — она просто игнорируется в `binding`, а в лог пишется предупреждение (один раз на каждый уникальный `entity_name`).

---

## Клиент

### Указание обработчика

```lua
api.entities.set_handler(
    entities_tbl: table,
    handler: function(uid: number, def: number, dirty: table)
)
```

- `entities_tbl` — таблица с перечислением строковых айдишников сущностей.
- `handler` — обработчик изменения полей сущности:
  - `uid` — User-ID сущности.
  - `def` — Числовой индекс сущности.
  - `dirty` — Таблица с изменёнными кастомными полями сущности.

> [!NOTE]
> Если в компоненте сущности создать ивент `on_custom_field_update`, то при изменении кастомного поля сущности в ивент будут переданы ключ и значение поля.

### Десинхронные сущности

```lua
api.entities.desync(name: string)
```

Принимает строковый айди сущности и делает её десинхронной. Десинхронные сущности видны только клиенту. Их можно заспавнить через `entities.spawn` на клиенте, и при этом они не будут отслеживаться стандартными методами ядра.

```lua
api.entities.sync(name: string)
```

Принимает строковый айди сущности и делает её синхронной. Синхронные сущности нельзя заспавнить через `entities.spawn` на клиенте, и они будут отслеживаться стандартными методами ядра.
