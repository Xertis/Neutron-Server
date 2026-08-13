# Конфиг сервера

После первого запуска сервера в папке `root/config` появится файл `server_config.json` со следующим содержимым:

```json
{
  "game": {
    "content_packs": ["base"],
    "plugins": [],
    "worlds": {
      "overworld": {
        "seed": "86935665463",
        "generator": "base:demo",
        "rules": {
          "cheat-commands": true
        }
      }
    },
    "main_world": "overworld"
  },
  "server": {
    "version": "0.31.0",
    "max_players": 16,
    "short_description": "MasterServer",
    "description": "",
    "port": 22003,
    "http_enabled": true,
    "auto_save_interval": 5,
    "chunks_loading_distance": 4,
    "chunks_loading_speed": 4,
    "password_auth": false,
    "last_session_lifetime": 30,
    "dev_mode": false,
    "shallow_dev_mode": true,
    "shutdown_timeout": -1,
    "kick_threshold_timeout": 30,
    "whitelist": [],
    "whitelist_ip": [],
    "blacklist": []
  },
  "roles": {
    "default_role": "member",
    "member": {
      "priority": 1,
      "rules": {
        "allow-content-access": true,
        "allow-flight": true,
        "allow-noclip": true,
        "allow-attack": true,
        "allow-destroy": true,
        "allow-cheat-movement": true,
        "allow-debug-cheats": true,
        "allow-fast-interaction": true
      },
      "permissions": {
        "role_management": true,
        "time_management": true
      }
    }
  }
}
```

## game

В разделе **game** определяются настройки игры и миров:

| Поле | Описание |
|------|----------|
| `content_packs` | Массив идентификаторов контент-паков. |
| `plugins` | Массив идентификаторов серверных плагинов. |
| `worlds` | Список миров и их настроек. |
| `main_world` | Имя мира, который будет запускаться при старте сервера. |

> [!WARNING]
> Изменение `content_packs` и `plugins` вступают в силу только при создании НОВОГО мира
> Если изменить паки или плагины для уже существующего мира, изменения применены не будут

Каждый мир может содержать дополнительные настройки:

```json
"overworld": {
  "seed": "86935665463",
  "generator": "base:demo",
  "rules": {
    "cheat-commands": true
  }
}
```

| Поле | Описание |
|------|----------|
| `seed` | Сид генерации мира. |
| `generator` | Идентификатор генератора мира. |
| `rules` | Мировые правила, действующие только в данном мире. |

## server

В разделе **server** находятся настройки сервера:

| Поле | Описание |
|------|----------|
| `version` | Major-версия движка. |
| `max_players` | Максимальное количество игроков. |
| `short_description` | Краткое название сервера. |
| `description` | Полное описание сервера. |
| `port` | Порт сервера. |
| `http_enabled` | Запускать ли HTTP-сервер. |
| `auto_save_interval` | Интервал автосохранения мира (в минутах). |
| `chunks_loading_distance` | Максимальная дистанция загрузки чанков вокруг игроков. |
| `chunks_loading_speed` | Скорость загрузки чанков. |
| `password_auth` | Требовать ли ввод пароля при входе. |
| `last_session_lifetime` | Время (в минутах), в течение которого игрок может автоматически войти повторно без ввода пароля при совпадении IP-адреса. |
| `dev_mode` | Отключает проверку модов. |
| `shallow_dev_mode` | Работает только при включённом `dev_mode`; отключает только проверку хэшей модов, но не проверку их наличия. |
| `shutdown_timeout` | Время (в минутах), через которое сервер автоматически сохранит мир и завершит работу. Если значение меньше `0` или отсутствует, автоматическое выключение отключено. |
| `kick_threshold_timeout` | Максимальное время ожидания ответа от клиента (в секундах), после которого игрок будет отключён. |
| `whitelist` | Список разрешённых имён игроков. Если список пуст, вайтлист отключён. |
| `whitelist_ip` | Список разрешённых IP-адресов. |
| `blacklist` | Список запрещённых имён игроков. |

## roles

В разделе **roles** определяются роли игроков.

| Поле | Описание |
|------|----------|
| `default_role` | Роль, которая автоматически назначается новым игрокам. |

### Поля роли

```json
"member": {
  "priority": 1,
  "rules": { ... },
  "permissions": { ... }
}
```

| Поле | Описание |
|------|----------|
| `priority` | Приоритет роли. Роль не может изменять или управлять игроками, имеющими такой же или более высокий приоритет. |
| `rules` | Набор игровых возможностей, доступных игроку. |
| `permissions` | Набор прав. |

### Права

| Право | Описание |
|-------|----------|
| `role_management` | Управление ролями игроков. |
| `time_management` | Изменение времени в мире. |
