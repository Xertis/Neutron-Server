# db

**Содержание**
- [Создание БД](#создание-бд)
- [Типы данных](#типы-данных)
- [Session](#session)
- [CRUD операции](#crud-операции)
- [Особенности](#особенности)

## Создание БД

```lua
-- Регистрация базы данных
api.db.db.register() -> nil | number
```

- Если база данных уже существует, возвращает код **DatabaseExists**.

```lua
-- Проверка существования БД у пака
api.db.db.exists(pack: string) -> boolean
```

```lua
-- Авторизация
api.db.db.login() -> Session | number
```

- Возвращает сессию для управления БД. Если базы не существует, возвращает **DatabaseNotExists**.

```lua
-- Создание колонки
api.db.items.Column(column_type: string, [config: table]) -> Column
```

- Возвращает объект `Column: {column_type, config}`.
- `config` может содержать `{primary_key = true}`.
- Доступные типы для `primary_key`: `uint8`, `uint16`, `uint32`, `int64`.

## Типы данных

```lua
api.db.types = {
    codes = {
        null     = 0,
        int8     = 1,
        int16    = 2,
        int32    = 3,
        int64    = 4,
        uint8    = 5,
        uint16   = 6,
        uint32   = 7,
        string   = 8,
        norm8    = 9,
        norm16   = 10,
        float32  = 11,
        float64  = 12,
        bool     = 13
    },
    indexes = {
        [0] = "null",
        "int8", "int16", "int32", "int64",
        "uint8", "uint16", "uint32",
        "string", "norm8", "norm16",
        "float32", "float64", "bool"
    }
}
```

### Коды ошибок

| Код | Значение |
|-----|----------|
| `200` | Success |
| `101` | DatabaseExists |
| `102` | DatabaseNotExists |
| `201` | TableExists |

## Session

### Инициализация таблицы

```lua
local Column = api.db.items.Column
Session:init_table({
    __tablename__ = "users",
    id = Column("uint32", {primary_key = true}),
    name = Column("string"),
    hp = Column("uint8"),
    saturation = Column("uint8")
})
```

> [!NOTE]
> Если таблица не существует — она будет создана. В таблице обязательно должна быть колонка `primary_key` и **только одна**.

### Методы запросов

| Метод | Описание |
|-------|----------|
| `:order_by(field, [reverse])` | Сортирует результаты по полю. |
| `:first()` | Возвращает первый элемент. |
| `:last()` | Возвращает последний элемент. |
| `:all()` | Возвращает все элементы. |
| `:count()` | Возвращает количество элементов. |

### Полный пример запроса

```lua
local results = session:query("users")
    :filter({hp = {["=>"] = 15}})
    :filter({name = {["not_in"] = {"Jeremy", "Mark"}}})
    :order_by("hp", true)
    :limit(10)
    :all()
```

## CRUD операции

### Добавление

```lua
session:add("users", {
    name = "Mops",
    hp = 20
})
```

### Обновление

```lua
session:update("users", primary_key_value, {
    name = "Новое имя",
    hp = 10
})
```

### Удаление

```lua
session:delete("users", {
    {id = 1},
    {id = 2}
})
```

> [!NOTE]
> Если передана пустая таблица со значениями — очистит всю таблицу.

### Удаление таблицы

```lua
session:remove_table("users")
```

## Особенности

- Методы выбрасывают ошибки при нарушении условий (отсутствие таблицы, неверный `primary_key` и т.д.).
- Фильтрация поддерживает операторы: `==`, `~=`, `>`, `<`, `>=`, `<=`, `in`, `not_in`.
