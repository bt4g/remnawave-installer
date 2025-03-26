## Remnawave Installer

Этот скрипт предназначен для автоматизированной установки панели и ноды **Remnawave**.

**ВАЖНО!** Не используйте панель в production без полного понимания, что и как работает. Этот скрипт предназначен только для демонстрации работы Remnawave, не для ее использования в бою. Трафик между панелью и нодой не защищен!

Вы можете использовать Remnawave двумя способами:

- **Вариант 1 (Два сервера)**: Установка панели и ноды на разных серверах (рекомендуется)
- **Вариант 2 (Всё в одном)**: Установка панели и ноды на одном сервере (упрощенная установка)

### Вариант 1: Два сервера

Для полноценного использования вам понадобятся два отдельных сервера:

- Сервер для панели - он будет центром управления, но не будет содержать Xray ноду
- Сервер для ноды - он будет содержать Xray ноду и заглушку Self Steal для VLESS REALITY

Для этого варианта необходимо три домена (поддомена): один для панели, второй — для подписок и третий — для сайта-заглушки Self Steal, который размещается на сервере с нодой.

**Важно про настройку DNS:**

- Домены панели и подписок должны указывать на IP-адрес сервера с панелью
- Домен для сайта-заглушки Self Steal должен указывать на IP-адрес сервера с нодой

Рекомендуемый порядок установки:

1. Сначала установите панель и получите публичный ключ для вашей ноды.
2. Затем установите ноду, указав ранее полученный ключ.

**Важно!** После завершения установки **ноды**, чтобы панель ее подхватила, потребуется выполнить перезапуск **панели** в меню скрипта установки

### Вариант 2: Всё в одном (упрощенная установка)

Для упрощенной установки вы можете развернуть и панель, и ноду на одном сервере.

Для этого вам понадобится:

- Один сервер с Ubuntu
- Один домен, который будет использоваться для:
  - Панели управления
  - Подписок
  - Self Steal (заглушка для VLESS REALITY)

Этот вариант автоматически настраивает взаимодействие между панелью и нодой, что упрощает процесс установки и управления.
В этом варианте **недоступен** дополнительный сервис [Subscription templates](https://remna.st/subscription-templating/installation)
Это связано с тем, что этот сервис ожидает подписки в корне, а в этом варианте подписки находятся на пути /sub/

В этой конфигурации Remnawave нода (Xray в ней) обрабатывает весь входящий трафик на 443 порту. Все запросы, которые не являются Xray-proxy-соединениями уходят в dest fallback и перенаправляются в Caddy, который затем распределяет их по нужным сервисам (панель, selfsteal, подписки в зависимости от sni). Если в этом режиме остановить локальную Remnawave ноду, то панель перестанет быть доступна.

ВАЖНО! Для того, чтобы этот вариант конфигурации заработал, требуется сначала запустить панель на кастомном порту (третий вариант), установить и настроить локальную Remnawave ноду, в конфиге Xray в панели указать inbounds.port 443.

```
Клиент → 443 порт → Xray → (Прокси-соединения)
                      ↓
                     Caddy → Панель/Подписки/Selfsteal (в зависимости от SNI)
```

## Системные требования

- ОС: Ubuntu 22.04
- Пользователь с правами root (sudo)

## Установка

Для запуска установщика выполните следующую команду в терминале:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/xxphantom/remnawave-installer/refs/heads/main/dist/install_remnawave.sh)
```

<p align="center"><img src="./assets/menu.png" alt="Remnawave Installer Menu"></p>

### Установка панели Remnawave

1. После запуска скрипта выберите пункт **1) Установка панели Remnawave**.
2. Скрипт автоматически установит необходимые зависимости (Docker и другие).
3. Вам потребуется ввести:
   - Токен Telegram-бота / ID администратора и ID чата (если включите интеграцию с Telegram)
   - Основной **домен** для панели управления
   - Отдельный **домен** для подписок
   - Имя пользователя и пароль SuperAdmin (либо сгенерировать силами скрипта)
4. Скрипт зарегистрирует SuperAdmin в панели за вас и проведёт первичную настройку:
   - Запросит selfsteal домен для конфигурации
   - Сгенерирует конфиг Xray VLESS.
   - Получит публичный ключ для ноды и создаст хост

### Установка ноды Remnawave

1. Выберите пункт **2) Установка ноды Remnawave**.
2. Скрипт установит необходимые зависимости.
3. Вам потребуется ввести:
   - Домен для Steal-сайта.
   - Порт для подключения ноды.
   - Публичный ключ панели для ноды.

### Установка "Всё в одном" (панель + нода)

1. Выберите пункт **3) Установка "Всё в одном" (панель + нода)**.
2. Скрипт установит необходимые зависимости (Docker и другие).
3. Вам потребуется ввести:
   - Токен Telegram-бота / ID администратора и ID чата (если включите интеграцию с Telegram)
   - Ваш **домен**, который будет использоваться для панели, подписок и Self Steal
   - Порт для подключения ноды
   - Имя пользователя и пароль SuperAdmin (либо сгенерировать силами скрипта)
4. Скрипт автоматически настроит и запустит:
   - Панель управления Remnawave
   - Ноду Remnawave с Xray
   - Caddy для обработки HTTPS-запросов
   - Заглушку Self Steal
   - Страницу подписок

## Защита панели на основе URL-параметра

В Caddy добавлена дополнительная защита от обнаружения панели:

- Для доступа к панели необходимо открыть страницу вида:

  ```
  https://ВАШ_ДОМЕН_ПАНЕЛИ/auth/login?caddy=<SECRET_KEY>
  ```

- Параметр `?caddy=<SECRET_KEY>` устанавливает специальную Cookie `caddy=<SECRET_KEY>` в браузере.
- Если Cookie не установлена или параметр в запросе отсутствует, при обращении к панели пользователь увидит пустую страницу или ошибку 404 (в зависимости от запрошенного пути).

Таким образом, даже если злоумышленник будет сканировать хост или перебирать пути, без точного параметра и/или Cookie панель останется невидимой.

## Управление сервисами

После установки вы можете управлять сервисами с помощью команды `make` в соответствующих директориях:

### Для варианта "Два сервера":

- **Директория панели**: `~/remnawave/panel`
- **Директория Caddy**: `~/remnawave/caddy`
- **Директория remnawave-subscription-page**: `~/remnawave/remnawave-subscription-page`

- **Директория ноды**: `~/remnanode/node`
- **Директория сайта-заглушки**: `~/remnanode/selfsteal`

### Для варианта "Всё в одном":

- **Директория панели**: `~/remnawave/panel`
- **Директория Caddy**: `~/remnawave/caddy`
- **Директория ноды**: `~/remnawave/node`

Доступные команды:

- `make start` — Запуск и просмотр логов
- `make stop` — Остановка
- `make restart` — Перезапуск
- `make logs` — Просмотр логов

## Примечания

- Убедитесь, что у вас настроены DNS-записи для **всех** указанных доменов, направляющие на IP-адрес соответствующего сервера.
- При использовании варианта "Всё в одном" один домен используется для всех сервисов (панель, подписки, Self Steal).

## Благодарности

- [AsanFillter](https://github.com/AsanFillter/Remnawave-AutoSetup) за Remnawave-AutoSetup
- [eGamesAPI](https://github.com/eGamesAPI/remnawave-reverse-proxy) за remnawave-reverse-proxy
