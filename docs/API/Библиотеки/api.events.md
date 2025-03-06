**events** - позволяет передавать сообщения между серверными модами и клиентскими

```lua
api.events.tell(
	pack: string, 
	event: string, 
	client: Client, 
	bytes: table<bytes>
)
```
Отправляет моду **pack** клиента **client** ивент типа **event**, внутри которого лежит массив байт **bytes**

```lua
api.events.echo(
	pack: string, 
	event: string, 
	bytes: table<bytes>
)
```
Отправляет моду **pack** всем клиентам ивент типа **event**, внутри которого лежит массив байт **bytes**


```lua
client_api.events.send(
	pack: string, 
	event: string, 
	bytes: table<bytes>
)
```
Отправляет моду **pack** сервера ивент типа **event**, внутри которого лежит массив байт **bytes**

```lua
api.events.on(
	pack: string, 
	event: string, 
	func: function table<bytes>)
)
```
Регистрирует функцию на вызов, при получении ивента **event** паком **pack**, внутрь которой будут переданы значения в виде массива байт
