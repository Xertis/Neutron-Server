Система **rpc** является обёрткой над **events**, предоставляет удобный способ сериализации и десериализации данных во время отправки

1. **Отправка события конкретному клиенту:**
```lua
api.rpc.emitter.create_tell(pack: string, event: string) -> function (client: Client, ...)
```
   - Возвращает функцию, которая принимает клиент, которому надо отправить ивент и неограниченное кол-во аргументов. Полученные аргументы сериализуются с помощью проприетарного bson и отправляются клиенту

2. **Отправка события всем клиентам:**
```lua
api.rpc.emitter.create_echo(pack: string, event: string) -> function (...)
```
   - Идентичен **rpc.create_tell**, за исключением того, что возвращаемая функция не принимает **client** и отправляет ивент всем клиентам