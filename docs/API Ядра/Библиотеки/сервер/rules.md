# Rules

## Определение правила

```lua
-- api.rules.define(name: string, properties: { default: any, level: "player"|"world" }) -> Rule
local FlightRule = api.rules.define("allow-flight", { default = true, level = "player" })
```
Регистрирует правило и возвращает объект `Rule`.

`level` обязателен и должен быть либо `"player"`, либо `"world"` — определяет, в каком хранилище живёт значение правила: у конкретного игрока или у мира. Значение правила с level=`"player"` независимо для каждого игрока, с level=`"world"` — общее для всех игроков в мире.

> [!WARNING]
> `api.rules.define` должен вызываться в **shared**-коде — том, что выполняется одинаково и на клиенте,
> и на сервере (например, в `content.lua` пака).
>
> Имя, `default` и
> `level` должны совпадать в обеих средах: сервер — источник истины для текущего значения, а клиент
> использует `default` до получения первого пакета изменения и полагается на то же имя правила для подписки
> через `Rule:listen`. 
>
>Если правило определено только на сервере, клиентская часть мода не сможет ни
> прочитать, ни подписаться на его значение; если определения разойдутся (разный `default`), клиент
> будет показывать неверное значение до первого обновления с сервера.

> [!WARNING]
> Повторный `api.rules.define` с уже занятым именем кидает ошибку.
> Если код может выполняться повторно, используйте
> `api.rules.define_if_absent`.

## Условное определение

```lua
-- api.rules.define_if_absent(name: string, properties: table) -> Rule
local FlightRule = api.rules.define_if_absent("allow-flight", { default = true, level = "player" })
```
То же самое, что `define`, но вместо ошибки при повторном вызове возвращает уже существующий объект `Rule`, если правило с этим именем было определено раньше — в том числе другим модом. Безопасно вызывать многократно.

## Проверка существования

```lua
-- api.rules.is_defined(name: string) -> boolean
if not api.rules.is_defined("allow-flight") then
    ...
end
```

## Получение объекта правила

```lua
-- api.rules.get_rule(name: string) -> Rule | nil
local rule = api.rules.get_rule("allow-flight")
```
Возвращает объект `Rule`, если правило было определено, иначе `nil`. Объект нужен для чтения/установки значения через `players`/`worlds` и для подписки на изменения.

## Чтение и установка значения

```lua
-- api.rules.players.get_value(player: Player, rule: Rule) -> any
-- api.rules.players.set_value(player: Player, rule: Rule, value: any)
local rule = api.rules.get_rule("allow-flight")
local value = api.rules.players.get_value(player, rule)
api.rules.players.set_value(player, rule, false)
```
```lua
-- api.rules.worlds.get_value(world: World, rule: Rule) -> any
-- api.rules.worlds.set_value(world: World, rule: Rule, value: any)
local rule = api.rules.get_rule("cheat-commands")
local value = api.rules.worlds.get_value(world, rule)
api.rules.worlds.set_value(world, rule, true)
```
`set_value` вызывает всех подписчиков, зарегистрированных через `Rule:listen`, и рассылает клиентам обновлённое значение.

> [!NOTE]
> Актуальное значение всегда читается через `players.get_rule`/`worlds.get_rule` с явной передачей
> игрока/мира, потому что у одного правила может быть разное значение для разных игроков (level=`"player"`)
> или разных миров (level=`"world"`).

## Все значения для игрока

```lua
-- api.rules.players.get_all_values(player: Player) -> { [name: string] = value }
local values = api.rules.players.get_all_values(player)
if values["allow-content-access"] then ... end
```
Возвращает таблицу со значениями **всех** зарегистрированных правил для данного игрока — и его личных (`level = "player"`), и общих правил его текущего мира (`level = "world"`).

## Объект Rule

```lua
-- Rule:listen(handler: function(obj: Player|World, value: any)) -> id: string
local id = rule:listen(function(obj, value)
    print("rule changed to", value, "for", obj)
end)
```
Подписывает `handler` на изменения значения правила. `obj` — игрок или мир, для которого значение было изменено (зависит от `rule.level`). Возвращает id для последующего удаления через `Rule:unlisten`.

```lua
-- Rule:unlisten(id: string)
rule:unlisten(id)
```
Удаляет обработчик по id, если он существует.
