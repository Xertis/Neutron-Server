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

4. **Получение роли:**
```lua
api.accounts.roles.get(account: Account) -> table
```
   - Возвращает конфиг роли по аккаунту

5. **Получение правил аккаунта:**
```lua
api.accounts.roles.get_rules(account: Account, [опционально] category: boolean) -> table
```
   - Возвращает таблицу правил роли по аккаунту
   - Category - категория тех правил, которые надо вернуть (false -> game_rules / true  -> server_rules)

6. **Сравнение приоритета ролей:**
```lua
api.accounts.roles.is_higher(role1: table, role2: table) -> boolean
```
   - Возвращает `true` если первая роль имеет больший приоритет, чем вторая

7. **Проверка на существование роли:**
```lua
api.accounts.roles.exists(role: table) -> boolean
```
   - Возвращает `true` если роль существует