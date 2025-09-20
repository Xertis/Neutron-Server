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

3. **Получение клиента аккаунта по имени:**
```lua
api.accounts.get_client_by_name(username: String) -> Client
```
   - Возвращает класс типа **Client** игрока с ником **username**.

4. **Кик аккаунта:**
```lua
api.accounts.kick(account: Account, [опционально] reason: string, [опционально] soft: Boolean)
```
   - Кикает аккаунт **account** с сервера с причиной **reason**
   - Если **soft** равен **true**, то кик произойдёт не сразу, а после обработки пакетов, что обеспечит гарантированную отправку сообщения с причиной ошибки

5. **Получение роли:**
```lua
api.accounts.roles.get(account: Account) -> table
```
   - Возвращает конфиг роли по аккаунту

6. **Получение правил аккаунта:**
```lua
api.accounts.roles.get_rules(account: Account, [опционально] category: boolean) -> table
```
   - Возвращает таблицу правил роли по аккаунту
   - Category - категория тех правил, которые надо вернуть (false -> game_rules / true  -> server_rules)

7. **Сравнение приоритета ролей:**
```lua
api.accounts.roles.is_higher(role1: table, role2: table) -> boolean
```
   - Возвращает `true` если первая роль имеет больший приоритет, чем вторая

8. **Проверка на существование роли:**
```lua
api.accounts.roles.exists(role: table) -> boolean
```
   - Возвращает `true` если роль существует