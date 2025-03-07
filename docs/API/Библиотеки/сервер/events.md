Система **events** позволяет обмениваться сообщениями между серверными и клиентскими модами.

1. **Отправка события конкретному клиенту:**
```lua
api.events.tell(pack: string, event: string, client: Client, bytes: table<bytes>)
```
   - Отправляет событие **event** с данными **bytes** моду **pack** на стороне указанного клиента **client**.

2. **Отправка события всем клиентам:**
```lua
api.events.echo(pack: string, event: string, bytes: table<bytes>)
```
   - Отправляет событие **event** с данными **bytes** моду **pack** всем подключённым клиентам.

4. **Регистрация обработчика события:**
```lua
api.events.on(pack: string, event: string, func: function(table<bytes>))
```
   - Регистрирует функцию **func**, которая будет вызвана при получении события **event** от мода **pack**. В функцию передаются данные **bytes**.