# rules

**Содержание**
- [Сервер](#сервер)
  - [Определение правила](#определение-правила)
  - [Условное определение](#условное-определение)
  - [Проверка существования](#проверка-существования)
  - [Получение объекта правила](#получение-объекта-правила)
  - [Чтение и установка значения](#чтение-и-установка-значения)
  - [Все значения для игрока](#все-значения-для-игрока)
  - [Объект Rule](#объект-rule)
- [Клиент](#клиент)
  - [Определение правила](#определение-правила-1)
  - [Условное определение](#условное-определение-1)
  - [Проверка существования](#проверка-существования-1)
  - [Получение объекта правила](#получение-объекта-правила-1)
  - [Объект Rule](#объект-rule-1)

> [!WARNING]
> `api.rules.define` должен вызываться в **shared**-коде — том, что выполняется одинаково и на клиенте, и на сервере.

---

## Сервер

### Определение правила

```lua
api.rules.define(name: string, properties: { default: boolean, level: "player"|"world" }) -> Rule
```

```lua
local FlightRule = api.rules.define("allow-flight", { default = true, level = "player" })
```

- `level` обязателен: `"player"` или `"world"`.
  - `"player"` — значение независимо для каждого игрока.
  - `"world"` — общее для всех игроков в мире.

> [!WARNING]
> Повторный `api.rules.define` с уже занятым именем кидает ошибку. Если код может выполняться повторно, используйте `api.rules.define_if_absent`.

### Условное определение

```lua
api.rules.define_if_absent(name: string, properties: table) -> Rule
```

То же самое, что `define`, но вместо ошибки при повторном вызове возвращает уже существующий объект `Rule`.

### Проверка существования

```lua
api.rules.is_defined(name: string) -> boolean
```

### Получение объекта правила

```lua
api.rules.get_rule(name: string) -> Rule | nil
```

### Чтение и установка значения

```lua
-- Для игроков
api.rules.players.get_value(player: Player, rule: Rule) -> boolean
api.rules.players.set_value(player: Player, rule: Rule, value: boolean)

-- Для миров
api.rules.worlds.get_value(world: World, rule: Rule) -> boolean
api.rules.worlds.set_value(world: World, rule: Rule, value: boolean)
```

`set_value` вызывает всех подписчиков, зарегистрированных через `Rule:listen`, и рассылает клиентам обновлённое значение.

### Все значения для игрока

```lua
api.rules.players.get_all_values(player: Player) -> { [name: string] = value }
```

Возвращает таблицу со значениями **всех** зарегистрированных правил для данного игрока.

### Объект Rule

```lua
-- Подписка на изменения
Rule:listen(handler: function(obj: Player|World, value: boolean)) -> id: string

-- Отписка
Rule:unlisten(id: string)
```

---

## Клиент

### Определение правила

```lua
api.rules.define(name: string, properties: { default: boolean}) -> Rule
```

На клиенте у `Rule` игнорируется параметр `level` — правило всегда одно, локальное для текущего игрока.

### Условное определение

```lua
api.rules.define_if_absent(name: string, properties: table) -> Rule
```

### Проверка существования

```lua
api.rules.is_defined(name: string) -> boolean
```

### Получение объекта правила

```lua
api.rules.get_rule(name: string) -> Rule | nil
api.rules.get_value(rule: Rule) -> boolean
```

### Объект Rule

```lua
Rule:listen(handler: function(value: boolean)) -> id: string
Rule:unlisten(id: string)
```

> [!NOTE]
> У `Rule` на клиенте нет сеттеров: значения задаёт сервер. `api.rules` — read-only обёртка.
