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

---

## Сервер

Модуль `api.entities` обеспечивает управление сущностями (мобами) на сервере, включая регистрацию, синхронизацию данных и обработку событий спавна/деспавна.

### Регистрация сущности

```lua
entities.register(entity_name, config, [spawn_handler])
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
    [optional] on_client_spawn = function(player, uid)
        -- Вызывается при первом появлении сущности на клиенте
        -- Принимает объект игрока и uid сущности
        -- Возвращает таблицу аргументов, которая будет отправлена на клиент
        return { ... }
    end,

    [optional] on_client_despawn = function(player, uid)
        -- Вызывается при удалении сущности на клиенте
    end,

    [optional] standard_fields = {
        tsf_pos = {
            maximum_deviation = number,
            evaluate_deviation = function(dist, cur_val, client_val)
            end
        }
        -- Другие поля...
    },

    [optional] custom_fields = {
        hp = {
            maximum_deviation = number,
            evaluate_deviation = function(dist, cur_val, client_val),
            provider = function(uid, field_name)
            end
        }
    },

    [optional] textures = {
        key1 = {
            maximum_deviation = number,
            evaluate_deviation = function(dist, cur_val, client_val),
            [optional] provider = function(uid, field_name)
        }
    },

    [optional] models = {
        [index] = {
            maximum_deviation = number,
            evaluate_deviation = function(dist, cur_val, client_val),
            [optional] provider = function(uid, field_name)
        }
    },

    [optional] matrix = {
        [index] = {
            maximum_deviation = number,
            evaluate_deviation = function(dist, cur_val, client_val),
            [optional] provider = function(uid, field_name)
        }
    },

    [optional] components = {
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

### Типы полей

#### `standard_fields`

Поля, привязанные к встроенным свойствам сущности (`entity.transform`, `entity.rigidbody` и т.п.), которые ядро умеет читать напрямую без явного `provider`. Пример — `tsf_pos`, получаемое через `entity.transform:get_pos()`.

```lua
standard_fields = {
    tsf_pos = {
        maximum_deviation = 0.5,
        evaluate_deviation = entities.eval.VectorNotEquals
        -- значение берётся из entity.transform:get_pos()
    }
}
```

#### `custom_fields`

Произвольные поля, не имеющие соответствия во встроенных свойствах сущности (HP, состояние, кастомные флаги и т.п.).

- `provider` **обязателен** и должен возвращать значение произвольного типа.
- Сигнатура: `function(uid, field_name)` — должна вернуть текущее значение поля для сущности `uid`.

```lua
custom_fields = {
    hp = {
        maximum_deviation = 1,
        evaluate_deviation = entities.eval.NotEquals,
        provider = function(uid, field_name)
            return health.get(uid)
        end
    }
}
```

#### `textures`

Управляют текстурами модели сущности. Ключ секции — **произвольное имя текстуры**, а не числовой индекс.

- По умолчанию значение читается из `entity.skeleton` (текстура, назначенная на соответствующий слот скелета), но это сработает только если в коде самостоятельно устанавливается значение для `entity.skeleton`.
- Так как `entity.skeleton` недоступен в headless-режиме и реализован через патч движка, можно указать `provider`, который должен возвращать `string` — имя текстуры.

```lua
textures = {
    skin = {
        maximum_deviation = 0,
        evaluate_deviation = entities.eval.NotEquals,
        provider = function(uid, field_name)
            return entity_skins[uid]
        end
    }
}
```

#### `models`

Отвечают за модели костей. Ключ секции — **числовой индекс** кости в скелете.

- По умолчанию значение (какая модель назначена на индекс) читается из `entity.skeleton`.
- Есть опциональный `provider`, аналогично `textures`, который должен возвращать `string` — имя модели.

```lua
models = {
    [1] = {
        maximum_deviation = 0,
        evaluate_deviation = entities.eval.NotEquals,
        provider = function(uid, field_name)
            return models[uid][1]
        end
    }
}
```

#### `matrix`

Синхронизирует матрицы трансформации отдельных костей скелета. Ключ — **числовой индекс** кости в скелете.

- По умолчанию читается из `entity.skeleton` (матрица соответствующего узла).
- Есть опциональный `provider`, аналогично `textures` и `models`,
должен возвращать матрицу трансформации.
- Для сравнения матриц как векторных наборов чисел удобно использовать `entities.eval.VectorNotEquals`, а не `NotEquals` (устойчивость к погрешностям float).

```lua
matrix = {
    [0] = {
        maximum_deviation = 0.001,
        evaluate_deviation = entities.eval.VectorNotEquals,
        provider = function(uid, field_name)
            return bone_matrices[uid][0]
        end
    }
}
```

#### `components`

Включают/выключают компоненты сущности у клиента.

- `provider` **обязателен** и должен возвращать `bool`.
- `true` → компонент включается на клиенте, `false` → выключается.
- Так как значение бинарное, `evaluate_deviation` обычно задают как `entities.eval.NotEquals`.

```lua
components = {
    logic = {
        maximum_deviation = 0,
        evaluate_deviation = entities.eval.NotEquals,
        provider = function(uid, field_name)
            return false
        end
    }
}
```

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
3. Для сущности типа игрока, принадлежащей самому клиенту, которому она отправляется (т.е. это его собственный игровой персонаж), синхронизируются **только `custom_fields`**.

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

> [!NOTE]
> По умолчанию **все** сущности на клиенте синхронные
