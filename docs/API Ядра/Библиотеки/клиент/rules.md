# Rules

>[!WARNING]
> Перед чтением документации к клиентской обёртке **api.rules**, рекомендуется прочитать документацию
> к серверной части **api.rules**.

## Определение правила

```lua
-- api.rules.define(name: string, properties: { default: any, [handler]: function }) -> Rule
local FlightRule = api.rules.define("allow-flight", { default = true })
```
Регистрирует правило через `rules.create` и возвращает объект `Rule` поверх него.

На клиенте у `Rule` нет `level` — в отличие от сервера, где `player`/`world` два разных хранилища, на клиенте правило всегда одно, локальное для текущего игрока/мира, и разделять нечего.

> [!WARNING]
> Повторный `api.rules.define` с уже занятым именем кидает ошибку.
> Если код может выполняться повторно, используйте
> `api.rules.define_if_absent`.

## Условное определение

```lua
-- api.rules.define_if_absent(name: string, properties: table) -> Rule
local FlightRule = api.rules.define_if_absent("allow-flight", { default = true })
```
То же самое, что `define`, но вместо ошибки при повторном вызове возвращает уже существующий объект `Rule`, если правило с этим именем было определено раньше — в том числе другим модом. Безопасно вызывать многократно.

## Проверка существования

```lua
-- api.rules.is_defined(name: string) -> boolean
if not api.rules.is_defined("allow-flight") then
    ...
end
```
Проверяет, было ли правило зарегистрировано через `define`/`define_if_absent`.

## Получение объекта правила

```lua
-- api.rules.get_rule(name: string) -> Rule | nil
local rule = api.rules.get_rule("allow-flight")
```
Возвращает объект `Rule`, если правило было определено через `define`/`define_if_absent`, иначе `nil`.

```lua
-- api.rules.get_value(rule: Rule) -> any
local value = api.rules.get_value(rule)
```
Возвращает текущее значение правила

## Объект Rule

```lua
-- Rule:listen(handler: function(value)) -> id: string
local id = rule:listen(function(value)
    print("allow-flight changed to", value)
end)
```
Подписывает `handler` на изменения значения правила. Возвращает id для последующего удаления через `Rule:unlisten`.

```lua
-- Rule:unlisten(id: string)
rule:unlisten(id)
```
Удаляет обработчик по id, если он существует.

> [!NOTE]
> У `Rule` нет сеттеров: значения правил на клиенте задаёт сервер, `api.rules` — read-only обёртка.
>
> Если правило ещё не определено через `define`, но нужно просто прочитать значение или подписаться
> без создания `Rule`-объекта — используйте базовые `rules.get`/`rules.listen`/`rules.unlisten`
> напрямую, как описано в движковой документации.
