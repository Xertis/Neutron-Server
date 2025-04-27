Система **accounts** позволяет получать и управлять аккаунтами игроков.

1. **Получение аккаунта игрока:**
```lua
api.accounts.get_account_by_name(username: string) -> Account
```
   - Возвращает класс типа **Account** игрока с ником **username**

2. **Получение клиента аккаунта:**
```lua
api.accounts.get_client(account: Account) -> Client
```
   - Возвращает класс типа **Client** игрока с аккаунтом **account**.

3. **Кик аккаунта:**
```lua
api.accounts.kick(account: Account)
```
   - Кикает аккаунт **account** с сервера