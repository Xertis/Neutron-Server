Система **rpc** является обёрткой над **events**, предоставляет удобный способ сериализации и десериализации данных во время отправки

# Методы отправки
```lua
-- Возвращает функцию, которая отправляет данные клиенту в формате bson.
api.rpc.emitter.create_tell(pack: string, event: string) -> function (client: Client, ...)

-- Идентичен create_tell, за исключением того, что отправляет данные ВСЕХ клиентам
api.rpc.emitter.create_echo(pack: string, event: string) -> function (...)
```

## Методы чтения
```lua
-- Регистрирует обработчик на ивент пака, в отличии от events.on, в обработчик поступает десериализованный bson из полученных байт
api.rpc.handler.on(pack: string, event: string, handler: function (client, bson))
```