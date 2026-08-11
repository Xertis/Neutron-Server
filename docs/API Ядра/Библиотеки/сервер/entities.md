# Система управления сущностями

Модуль `api.entities` обеспечивает управление сущностями (мобами) на сервере,
включая регистрацию, синхронизацию данных и обработку событий спавна/деспавна.

### 1.1. Структура модуля

#### Доступные поля сущностей
- **standard_fields**:
  - `tsf_pos` (vec3): позиция сущности `{x, y, z}`.
  - `tsf_rot` (vec3): вращение сущности.
  - `tsf_size` (vec3): размер трансформации.
  - `body_phys` (boolean): состояние физики (вкл/выкл).
  - `body_size` (vec3): размер физического тела.
- **custom_fields**: пользовательские поля, например, `hp`.
- **textures**: Ключи (string) текстур с их значениями
- **models**: Индексы (number) костей с их моделями
- **matrix**: Индексы (number) костей с их матрицами
- **components**: Названия компонентов сущностей со значением их активности (true/false)

### 1.2. Основные функции

#### Регистрация сущности
```lua
entities.register(entity_name, config, spawn_handler)
```
**Параметры:**
- `entity_name` (string): имя типа сущности (например, `"example:zombie"`).
- `config` (table): конфигурация полей сущности.
- `spawn_handler` (function (name, args, client) ): вызывается в том случае, когда клиент пытается заспавнить зарегистрированную сущность

**Сигнатура config:**
```lua
{
    -- Вызывается при первом появлении сущности на клиенте
    -- Принимает объект игрока и uid сущности.
    -- Возвращает таблицу аргументов, которая будет отправлена на клиент
    on_client_spawn = function(player, uid)
        ...
        return { ... } -- args: table | nil
    end,

    -- Вызывается при удалении сущности на клиенте
    -- Принимает объект игрока и uid сущности.
    on_client_despawn = function(player, uid)
        ...
    end,

    standard_fields = {
        tsf_pos = {
            maximum_deviation = number, -- Максимальное отклонение
            evaluate_deviation = function(dist, cur_val, client_val) -- Оценка отклонения
        },
        -- Другие поля...
    },
    custom_fields = {
        hp = {
            maximum_deviation = number,
            evaluate_deviation = function(dist, cur_val, client_val),
            provider = function(uid, field_name) -- Получение значения поля
        }
    },
    textures = {
        key1 = {
            maximum_deviation = number, -- Максимальное отклонение
            evaluate_deviation = function(dist, cur_val, client_val) -- Оценка отклонения
            [Необязательно] provider = function(uid, field_name) -- Получение значения поля
        },
    }
    models = {
        [index] = {
            maximum_deviation = number, -- Максимальное отклонение
            evaluate_deviation = function(dist, cur_val, client_val) -- Оценка отклонения
            [Необязательно] provider = function(uid, field_name) -- Получение значения поля
        },
    }
    matrix = {
        [index] = {
            maximum_deviation = number, -- Максимальное отклонение
            evaluate_deviation = function(dist, cur_val, client_val) -- Оценка отклонения
            [Необязательно] provider = function(uid, field_name) -- Получение значения поля
        },
    }
    components = {
        component = {
            maximum_deviation = number, -- Максимальное отклонение
            evaluate_deviation = function(dist, cur_val, client_val) -- Оценка отклонения
            provider = function(uid, field_name) -- Получение значения поля, всегда bool
            -- Если provider вернёт true, компонент включится у клиента, если false - выключится
        },
    }
}
```
> [!NOTE]
> При регистрации ключи `models` автоматически приводятся к числовому типу (`tonumber`). Если ключ невозможно привести к числу, в лог выводится предупреждение `"Entity model indexes must be number"`, а само значение из конфига пропадает — используйте числовые индексы напрямую, чтобы не полагаться на автоприведение.

- **maximum_devitation** - Максимальное отклонение между значениями поля на сервере и клиенте
- **provider** - Функция, которая вызывается для получения значения поля
- **evalute_deviation** - Функция, вычисляющая значение отклонения на основе:
    1. Расстояния до игрока (dist: number),
    2. Действительного значения поля (cur_val: any),
    3. Значения поля на клиенте (client_val: any)

    функция возвращает величину отклонения, назовём это **d**, после чего, если значение выражения: `math.abs(d) > maximum_devitation` истинно, то новое значение поля отправляется на клиент

>[!NOTE]
> В связи с тем, что entity.skeleton по умолчанию не доступен в headless режиме, поля из **textures**, **models**, **matrix**
> Имеют альтернативный способ получения значений из **provider**

#### Вспомогательные функции
Перечисленные ниже вспомогательные функции можно использовать для evalute_deviation

```lua
-- Возвращает math.huge, если значения на клиенте и на сервере НЕ равны, иначе 0.
-- Для таблиц (vec3, vec2 и т.п.) сравнение идёт через глубокое сравнение
-- (table.deep_equals), а не по ссылке.
entities.eval.NotEquals

-- Предназначена для векторных полей (vec3/vec2, массивы чисел).
-- Возвращает math.huge, если хотя бы одна компонента client_val
-- отличается от соответствующей компоненты cur_val больше чем на 0.001,
-- иначе 0. Если у client_val нет компоненты по индексу, она считается равной 0.
entities.eval.VectorNotEquals

-- Всегда возвращает math.huge
entities.eval.Always

-- Всегда возвращает 0
entities.eval.Never
```

> [!TIP]
> Для полей типа vec3 (`tsf_pos`, `body_size` и т.п.) предпочтительнее использовать `VectorNotEquals`, а не `NotEquals`: она не требует точного побайтового совпадения и устойчива к погрешностям с плавающей точкой, тогда как `NotEquals` через `deep_equals` сравнивает значения на точное равенство.

#### Доступные типы
```lua
types = {
    Custom = "custom_fields",
    Standard = "standard_fields",
    Models = "models",
    Matrix = "matrix",
    Textures = "textures",
    Components = "components"
}
```
`entities.types` — перечисление ключей секций конфига сущности (`custom_fields`, `standard_fields`, `models`, `matrix`, `textures`, `components`). Это чисто справочная/константная таблица для внешнего кода: она не используется модулем сама по себе, а служит для того, чтобы обращаться к секциям конфига через `entities.types.Matrix` вместо строкового литерала `"matrix"`, избегая опечаток и хардкода строк в нескольких местах мода.

### 1.4. Важные примечания
1. Данные моба не будут отправляться клиентам, если моб находится вне зоны прогрузки чанков.
2. Если данные сущности переданы на клиент, но сущность на клиенте не создана, то она автоматически будет создана на нулевых координатах. Из этого следует, что если на клиент были переданы данные сущности без позиции, то на клиенте сущность появится на нулевых координатах.
3. Спавн незарегистрированной сущности не приводит к ошибке — она просто игнорируется в `binding`, а в лог пишется предупреждение (один раз на каждый уникальный `entity_name`).
