Система **accounts** позволяет получать и управлять аккаунтами игроков.

1. **Получение аккаунта игрока:**
```lua
api.events.get_account_by_name(username: string) -> Account
```
   - Возвращает класс типа **Account** игрока с ником **username**

2. **Получение клиента аккаунта:**
```lua
api.events.get_client(account) -> Client
```
   - Возвращает класс типа **Client** игрока с аккаунтом **account**.