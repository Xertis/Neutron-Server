# events

**Содержание**
- [Сервер](#сервер)
  - [Отправка событий](#отправка-событий)
  - [Обработчики событий](#обработчики-событий)
- [Клиент](#клиент)
  - [Отправка события на сервер](#отправка-события-на-сервер)
  - [Регистрация обработчика](#регистрация-обработчика)

---

## Сервер

### Отправка событий

```lua
-- Отправляет событие с данными на сторону указанного клиента
api.events.tell(pack: string, event: string, client: Client, bytes: Bytearray)

-- Отправляет событие с данными всем подключённым клиентам
api.events.echo(pack: string, event: string, bytes: Bytearray)

-- Отправляет событие только тем клиентам, для которых selector вернул true
api.events.selective_echo(
    pack: string,
    event: string,
    bytes: Bytearray,
    selector: function(client): boolean
)
```

### Обработчики событий

```lua
api.events.on(
    pack: string,
    event: string,
    handler: function(Client, Bytearray)
)
```

Регистрирует функцию, которая будет вызвана при получении события.
В функцию передаются `Client` и данные `bytes`.

---

## Клиент

### Отправка события на сервер

```lua
api.events.send(pack: string, event: string, bytes: bytearray)
```

Отправляет событие с данными на сервер.

### Регистрация обработчика

```lua
api.events.on(pack: string, event: string, func: function(bytearray))
```

Регистрирует функцию, которая будет вызвана при получении события.
В функцию передаются данные `bytes`.
