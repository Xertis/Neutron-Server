Система **events** позволяет обмениваться сообщениями между серверными и клиентскими модами.

1. **Отправка события на сервер:**
```lua
api.events.send(pack: string, event: string, bytes: table<bytes>)
```
   - Отправляет событие **event** с данными **bytes** моду **pack** на сервер.

2. **Регистрация обработчика события:**
```lua
api.events.on(pack: string, event: string, func: function(table<bytes>))
```
   - Регистрирует функцию **func**, которая будет вызвана при получении события **event** от мода **pack**. В функцию передаются данные **bytes**.