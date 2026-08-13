# standard events

```lua
-- Вызывается при заходе игрока в мир
events.on("server:client_connected", function(client)
    print(client.account.username, "зашёл")
end)

-- Вызывается при выходе игрока из мира
events.on("server:client_disconnected", function(client)
    print(client.account.username, "вышел")
end)

-- Вызывается перед тем, как клиент будет отправлен в клиентский конвейер
events.on("server:client_pipe_start", function(client)
    print(client.account.username .. "перешёл на обработку")
end)

-- Вызывается в конце стартовой телепортации игрока
events.on("server:on_player_ready", function(client)
    print(client.player.username, "приземлился на землю")
end)

-- Вызывается каждый тик серверного движка
events.on("server:main_tick", function()
    print("Тик")
end)
```
