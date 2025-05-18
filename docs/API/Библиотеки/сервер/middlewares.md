# Система middlewares

Модуль `middlewares` позволяет добавлять промежуточные обработчики (middleware) для пакетов, которые вызываются перед их основной обработкой сервером.

## 1. Структура модуля

### Доступные пакеты
Модуль работает со следующими типами пакетов:
- `packets.ServerMsg` - пакеты, отправляемые сервером
- `packets.ClientMsg` - пакеты, отправляемые клиентом

## 2. Добавление middleware

```lua
api.middlewares.add_middleware(packet_type, middleware)
```

**Параметры:**
- `packet_type` (string) - тип пакета из `ServerMsg` или `ClientMsg`
- `middleware` (function) - функция-обработчик

**Сигнатура middleware:**
```lua
function(packet, client)
```
- `packet` (table) - данные полученного пакета
- `client` (Client) - клиент, от которого пришел пакет

**Возвращаемое значение:**
- `true` - продолжить обработку пакета
- `false/nil` - прекратить обработку пакета

## 3. Добавление общего обработчика для всех пакетов
```lua
api.middlewares.add_general_middleware(middleware)
```

## 4. Пример использования

```lua
middlewares.add_middleware("ClientMsg", function(packet, client)
    if not packet then
        return false
    end
    return true
end)
```

## 4. Важные примечания

1. Middleware не могут модифицировать содержимое пакета
