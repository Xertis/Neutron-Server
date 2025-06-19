# Система управления сущностями

Модуль `api.entities` обеспечивает управление сущностями (мобами) на сервере, включая регистрацию, синхронизацию данных и обработку событий спавна/деспавна.

### 1.1. Структура модуля

#### Доступные поля сущностей
- **standart_fields**:
  - `tsf_pos` (vec3): позиция сущности `{x, y, z}`.
  - `tsf_rot` (number): вращение сущности.
  - `tsf_size` (vec3): размер трансформации.
  - `body_phys` (boolean): состояние физики (вкл/выкл).
  - `body_size` (vec3): размер физического тела.
- **custom_fields**: пользовательские поля, например, `hp`.
- **textures**: Ключи текстур с их значениями
- **models**: Индексы (String) костей с их моделями
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
    standart_fields = {
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
        },
    }
    models = {
        ["index"] = { -- Индекс кости всегда надо записывать строчкой
            maximum_deviation = number, -- Максимальное отклонение
            evaluate_deviation = function(dist, cur_val, client_val) -- Оценка отклонения
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
- **maximum_devitation** - Максимальное отклонение между значениями поля на сервере и клиенте
- **provider** - Функция, которая вызывается для получения значения поля
- **evalute_deviation** - Функция, вычисляющая значение отклонения на основе:
    1. Расстояния до игрока (dist: number),
    2. Действительного значения поля (cur_val: any),
    3. Значения поля на клиенте (client_val: any)

    функция возвращает величину отклонения, назовём это **d**, после чего, если значение выражения: `math.abs(d) > maximum_devitation` истинно, то новое значение поля отправляется на клиент

#### Удаление сущности
```lua
entity:despawn()
```
Удаляет сущность на сервере и у клиентов

### 1.3. Функции игроков
```lua
entities.players.add_field(field_type: string, key: string, config: table)

entities.players.add_field(entities.types.Custom, "hp", {
        maximum_deviation = number,
        evaluate_deviation = function(0, cur_val, client_val),
        provider = function(uid, field_name)
})
```
- Нужно для создания новых полей игрока.
- Функция именно что ДОБАВЛЯЕТ новые поля ВСЕМ игрокам, а не заменяет старые, если создаваемое поле уже существует, функция вернёт **false** во избежании конфликтов

#### Вспомогательные функции
Перечисленные ниже вспомогательные функции можно использовать для evalute_deviation

```lua
entities.eval.NotEquals -- Возвращает math.huge если значения на клиенте и на сервере НЕ равны, иначе 0

entities.eval.Always -- Всегда возвращает math.huge

entities.eval.Never -- Всегда возвращает 0
```

#### Доступные типы
```lua
types = {
    Custom = "custom_fields",
    Standart = "standart_fields",
    Models = "models",
    Textures = "textures",
    Components = "components"
}
```

### 1.4. Важные примечания
1. Данные моба не будут отправляться клиентам, если моб находится вне зоны прогрузки или вне зоны видимости игрока
2. Если данные сущности переданы на клиент, но сущность на клиенте не создана, то она автоматически будет создана на нулевых координатах. Из этого следует, что если на клиент были переданы данные сущности без позиции, то на клиенте сущность появится на нулевых координатах