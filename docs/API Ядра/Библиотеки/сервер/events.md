## Содержание

* [Отправка событий](#отправка-событий)
* [Обработчики событий](#обработчики-событий)

## Отправка событий

```lua
-- Отправляет событие event с данными bytes моду pack
-- на сторону указанного клиента.
api.events.tell(
    pack: string,
    event: string,
    client: Client,
    bytes: Bytearray
)


-- Отправляет событие event с данными bytes моду pack
-- всем подключённым клиентам.
api.events.echo(
    pack: string,
    event: string,
    bytes: Bytearray
)

-- Отправляет событие event с данными
-- Вызывает `selector`, передавая туда клиент игрока
-- Если `selector` возвращает true - отправляет клиенту пакет
-- Иначе пакет не отправляется
api.events.selective_echo(
    pack: string,
    event: string,
    bytes: Bytearray,
    selector: function(client)
)
```

## Обработчики событий

```lua
-- Регистрирует функцию, которая будет вызвана
-- при получении события event от мода pack.
-- В функцию передаются Client и данные bytes.
api.events.on(
    pack: string,
    event: string,
    handler: function(Client, Bytearray)
)
```
