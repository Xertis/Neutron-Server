## Содержание

* [Получение аккаунтов и клиентов](#получение-аккаунтов-и-клиентов)
* [Управление аккаунтами](#управление-аккаунтами)
* [Роли и правила](#роли-и-правила)

## Получение аккаунтов и клиентов

```lua
-- Возвращает account игрока по identity
api.accounts.by_identity.get_account(identity: string) -> Account


-- Возвращает client игрока по identity
api.accounts.by_identity.get_client(identity: String) -> Client


-- Возвращает client игрока по account
api.accounts.get_client(account: Account) -> Client
```

## Управление аккаунтами

```lua
-- Кикает аккаунт с сервера по причине reason
-- Если soft == true, кик произойдёт после обработки пакетов
api.accounts.kick(
    account: Account,
    reason: string,
    soft: Boolean
)
```

## Роли и правила

```lua
-- Возвращает конфиг роли по аккаунту
api.accounts.roles.get(account: Account) -> table


-- Возвращает таблицу правил роли по аккаунту
-- category:
-- false -> game_rules
-- true  -> server_rules
-- или можно строчкой прописать нужную category
api.accounts.roles.get_rules(
    account: Account,
    category: boolean | string
) -> table


-- Возвращает true если первая роль имеет больший приоритет, чем вторая
api.accounts.roles.is_higher(role1: table, role2: table) -> boolean


-- Возвращает true если роль существует
api.accounts.roles.exists(role: table) -> boolean
```
