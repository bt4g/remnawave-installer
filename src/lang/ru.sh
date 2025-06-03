#!/bin/bash

# ===================================================================================
#                              РУССКИЕ ПЕРЕВОДЫ
# ===================================================================================

# Note: TRANSLATIONS array is already declared in i18n.sh

# Error messages
TRANSLATIONS_RU[error_root_required]="Ошибка: Этот скрипт должен быть запущен от имени root (sudo)"
TRANSLATIONS_RU[error_invalid_choice]="Неверный выбор, попробуйте снова."
TRANSLATIONS_RU[error_empty_response]="Ошибка: Пустой ответ от сервера при создании пользователя."
TRANSLATIONS_RU[error_failed_create_user]="Ошибка: Не удалось создать пользователя. HTTP статус:"
TRANSLATIONS_RU[error_passwords_no_match]="Пароли не совпадают. Попробуйте снова."
TRANSLATIONS_RU[error_enter_yn]="Пожалуйста, введите 'y' или 'n'."
TRANSLATIONS_RU[error_enter_number_between]="Пожалуйста, введите число от"

# Main menu
TRANSLATIONS_RU[main_menu_title]="Remnawave Panel Installer by uphantom v"
TRANSLATIONS_RU[main_menu_install_components]="Установить Панель/Ноду"
TRANSLATIONS_RU[main_menu_restart_panel]="Перезапустить панель"
TRANSLATIONS_RU[main_menu_remove_panel]="Удалить панель"
TRANSLATIONS_RU[main_menu_rescue_cli]="Remnawave Rescue CLI [Сброс админа]"
TRANSLATIONS_RU[main_menu_show_credentials]="Показать учетные данные панели"
TRANSLATIONS_RU[main_menu_exit]="Выход"
TRANSLATIONS_RU[main_menu_select_option]="Выберите опцию:"

# Installation menu
TRANSLATIONS_RU[install_menu_title]="Установка панели/ноды"
TRANSLATIONS_RU[install_menu_panel_only]="Только панель:"
TRANSLATIONS_RU[install_menu_panel_full_security]="\"FULL Caddy\" вариант установки панели (рекомендуется)"
TRANSLATIONS_RU[install_menu_panel_simple_security]="\"SIMPLE cookie\" вариант установки панели"
TRANSLATIONS_RU[install_menu_node_only]="Только нода:"
TRANSLATIONS_RU[install_menu_node_separate]="Только нода (для отдельного сервера)"
TRANSLATIONS_RU[install_menu_all_in_one]="All-in-One:"
TRANSLATIONS_RU[install_menu_panel_node_full]="Панель + Нода \"FULL Caddy\" вариант"
TRANSLATIONS_RU[install_menu_panel_node_simple]="Панель + Нода \"SIMPLE cookie\" вариант"
TRANSLATIONS_RU[install_menu_back]="Назад в главное меню"

# Common prompts
TRANSLATIONS_RU[prompt_yes_no_suffix]=" (y/n): "
TRANSLATIONS_RU[prompt_yes_no_default_suffix]=" (y/n) ["
TRANSLATIONS_RU[prompt_enter_to_continue]="Нажмите Enter для продолжения..."
TRANSLATIONS_RU[prompt_enter_to_return]="Нажмите Enter для возврата в меню..."

# Success/Info messages
TRANSLATIONS_RU[success_bbr_enabled]="BBR успешно включен"
TRANSLATIONS_RU[success_bbr_disabled]="BBR отключен, активен cubic + fq_codel"
TRANSLATIONS_RU[success_credentials_saved]="Учетные данные сохранены в файле:"
TRANSLATIONS_RU[success_installation_complete]="Установка завершена. Нажмите Enter для продолжения..."

# Warning messages
TRANSLATIONS_RU[warning_skipping_telegram]="Пропускаем интеграцию с Telegram."
TRANSLATIONS_RU[warning_bbr_not_configured]="BBR не был настроен в /etc/sysctl.conf"
TRANSLATIONS_RU[warning_enter_different_domain]="Пожалуйста, введите другой домен для"

# Info messages
TRANSLATIONS_RU[info_removing_bbr_config]="Удаление конфигурации BBR из /etc/sysctl.conf…"
TRANSLATIONS_RU[info_installation_directory]="Директория установки:"

# BBR related
TRANSLATIONS_RU[bbr_enable]="Включить BBR"
TRANSLATIONS_RU[bbr_disable]="Отключить BBR"

# Telegram configuration
TRANSLATIONS_RU[telegram_enable_notifications]="Хотите ли вы включить уведомления Telegram?"
TRANSLATIONS_RU[telegram_bot_token]="Введите токен вашего Telegram бота: "
TRANSLATIONS_RU[telegram_users_chat_id]="Введите ID чата пользователей: "
TRANSLATIONS_RU[telegram_nodes_chat_id]="Введите ID чата нод: "
TRANSLATIONS_RU[telegram_use_topics]="Хотите ли вы использовать темы Telegram?"
TRANSLATIONS_RU[telegram_users_thread_id]="Введите ID темы пользователей: "
TRANSLATIONS_RU[telegram_nodes_thread_id]="Введите ID темы нод: "

# Domain configuration
TRANSLATIONS_RU[domain_panel_prompt]="Введите домен панели (будет использоваться на сервере панели), например panel.example.com"
TRANSLATIONS_RU[domain_subscription_prompt]="Введите домен подписки (будет использоваться на сервере панели), например sub.example.com"
TRANSLATIONS_RU[domain_selfsteal_prompt]="Введите домен Selfsteal (будет использоваться на сервере ноды), например domain.example.com"

# Authentication
TRANSLATIONS_RU[auth_admin_username]="Введите имя пользователя администратора: "
TRANSLATIONS_RU[auth_admin_password]="Введите пароль администратора: "
TRANSLATIONS_RU[auth_admin_email]="Введите email администратора для Caddy Auth"
TRANSLATIONS_RU[auth_confirm_password]="Пожалуйста, подтвердите ваш пароль"

# Panel authentication
TRANSLATIONS_RU[panel_invalid_auth_type]="Неверный тип аутентификации"
TRANSLATIONS_RU[panel_auth_type_options]="Допустимые варианты: 'cookie' или 'full'"

# Results display
TRANSLATIONS_RU[results_secure_login_link]="Безопасная ссылка для входа (с секретным ключом):"
TRANSLATIONS_RU[results_user_subscription_url]="URL подписки пользователя:"
TRANSLATIONS_RU[results_admin_login]="Логин администратора:"
TRANSLATIONS_RU[results_admin_password]="Пароль администратора:"
TRANSLATIONS_RU[results_caddy_auth_login]="Логин авторизации Caddy:"
TRANSLATIONS_RU[results_caddy_auth_password]="Пароль авторизации Caddy:"
TRANSLATIONS_RU[results_remnawave_admin_login]="Логин администратора Remnawave:"
TRANSLATIONS_RU[results_remnawave_admin_password]="Пароль администратора Remnawave:"
TRANSLATIONS_RU[results_auth_portal_page]="Страница портала авторизации:"

# QR Code
TRANSLATIONS_RU[qr_subscription_url]="QR-код URL подписки"

# Password validation
TRANSLATIONS_RU[password_min_length]="Пароль должен содержать не менее"
TRANSLATIONS_RU[password_min_length_suffix]="символов."
TRANSLATIONS_RU[password_need_digit]="Пароль должен содержать хотя бы одну цифру."
TRANSLATIONS_RU[password_need_lowercase]="Пароль должен содержать хотя бы одну строчную букву."
TRANSLATIONS_RU[password_need_uppercase]="Пароль должен содержать хотя бы одну заглавную букву."
TRANSLATIONS_RU[password_try_again]="Попробуйте снова."

# Ports and network
TRANSLATIONS_RU[port_panel_prompt]="Введите порт панели (по умолчанию: 443): "
TRANSLATIONS_RU[port_node_prompt]="Введите порт ноды (по умолчанию: 2222): "
TRANSLATIONS_RU[port_caddy_local_prompt]="Введите локальный порт Caddy (по умолчанию: 9443): "

# Installation process
TRANSLATIONS_RU[installation_preparing]="Подготовка установки..."
TRANSLATIONS_RU[installation_starting_services]="Запуск сервисов..."
TRANSLATIONS_RU[installation_configuring]="Настройка..."

# Credentials
TRANSLATIONS_RU[credentials_found]="Учетные данные панели найдены:"
TRANSLATIONS_RU[credentials_not_found]="Файл учетных данных не найден!"
TRANSLATIONS_RU[credentials_file_location]="Файл учетных данных не существует по адресу:"
TRANSLATIONS_RU[credentials_reasons]="Обычно это означает:"
TRANSLATIONS_RU[credentials_reason_not_installed]="Панель еще не установлена"
TRANSLATIONS_RU[credentials_reason_incomplete]="Установка не была завершена успешно"
TRANSLATIONS_RU[credentials_reason_deleted]="Файл учетных данных был удален вручную"
TRANSLATIONS_RU[credentials_try_install]="Попробуйте сначала установить панель, используя опцию 1 из главного меню."

# CLI
TRANSLATIONS_RU[cli_container_not_running]="Контейнер Remnawave не запущен!"
TRANSLATIONS_RU[cli_ensure_panel_running]="Пожалуйста, убедитесь, что панель установлена и запущена."
TRANSLATIONS_RU[cli_session_completed]="Сессия CLI завершена успешно"
TRANSLATIONS_RU[cli_session_failed]="Сессия CLI завершилась неудачно или была прервана"

# Removal
TRANSLATIONS_RU[removal_installation_detected]="Обнаружена установка RemnaWave."
TRANSLATIONS_RU[removal_confirm_delete]="Вы уверены, что хотите полностью УДАЛИТЬ Remnawave? ЭТО УДАЛИТ ВСЕ ДАННЫЕ!!! Продолжить?"
TRANSLATIONS_RU[removal_previous_detected]="Обнаружена предыдущая установка RemnaWave."
TRANSLATIONS_RU[removal_confirm_continue]="Для продолжения необходимо УДАЛИТЬ предыдущую установку Remnawave. ЭТО УДАЛИТ ВСЕ ДАННЫЕ!!! Продолжить?"
TRANSLATIONS_RU[removal_complete_success]="Remnawave был полностью удален из вашей системы. Нажмите любую клавишу для продолжения..."
TRANSLATIONS_RU[removal_previous_success]="Предыдущая установка удалена."
TRANSLATIONS_RU[removal_no_installation]="Установка Remnawave не обнаружена в этой системе."

# Restart
TRANSLATIONS_RU[restart_panel_dir_not_found]="Ошибка: директория панели не найдена в /opt/remnawave!"
TRANSLATIONS_RU[restart_install_panel_first]="Пожалуйста, сначала установите панель Remnawave."
TRANSLATIONS_RU[restart_compose_not_found]="Ошибка: docker-compose.yml не найден в директории панели!"
TRANSLATIONS_RU[restart_installation_corrupted]="Установка панели может быть повреждена или неполная."
TRANSLATIONS_RU[restart_starting_panel]="Запуск основной панели..."
TRANSLATIONS_RU[restart_starting_subscription]="Запуск страницы подписки..."
TRANSLATIONS_RU[restart_success]="Панель успешно перезапущена"

# Services
TRANSLATIONS_RU[services_starting_containers]="Запуск контейнеров..."
TRANSLATIONS_RU[services_installation_stopped]="Установка остановлена"

# System
TRANSLATIONS_RU[system_distro_not_supported]="Дистрибутив"
TRANSLATIONS_RU[system_dependencies_success]="Все зависимости установлены и настроены."
TRANSLATIONS_RU[system_created_directory]="Создана директория:"
TRANSLATIONS_RU[system_installation_cancelled]="Установка отменена. Возврат в главное меню."

# Common prompts
TRANSLATIONS_RU[prompt_press_any_key]="Нажмите любую клавишу для продолжения..."

# Spinner messages
TRANSLATIONS_RU[spinner_generating_keys]="Генерация ключей x25519..."
TRANSLATIONS_RU[spinner_updating_xray]="Обновление конфигурации Xray..."
TRANSLATIONS_RU[spinner_registering_user]="Регистрация пользователя"
TRANSLATIONS_RU[spinner_getting_public_key]="Получение публичного ключа..."
TRANSLATIONS_RU[spinner_creating_node]="Создание ноды..."
TRANSLATIONS_RU[spinner_getting_inbounds]="Получение списка входящих соединений..."
TRANSLATIONS_RU[spinner_creating_host]="Создание хоста для"
TRANSLATIONS_RU[spinner_cleaning_services]="Очистка сервисов"
TRANSLATIONS_RU[spinner_force_removing]="Принудительное удаление контейнера"
TRANSLATIONS_RU[spinner_removing_directory]="Удаление директории"
TRANSLATIONS_RU[spinner_stopping_subscription]="Остановка контейнера remnawave-subscription-page"
TRANSLATIONS_RU[spinner_restarting_panel]="Перезапуск панели..."
TRANSLATIONS_RU[spinner_launching]="Запуск"
TRANSLATIONS_RU[spinner_updating_apt_cache]="Обновление кэша APT"
TRANSLATIONS_RU[spinner_installing_packages]="Установка пакетов:"
TRANSLATIONS_RU[spinner_starting_docker]="Запуск демона Docker"
TRANSLATIONS_RU[spinner_docker_already_running]="Демон Docker уже запущен"
TRANSLATIONS_RU[spinner_adding_user_to_group]="Добавление пользователя в группу"
TRANSLATIONS_RU[spinner_firewall_already_set]="Брандмауэр уже настроен"
TRANSLATIONS_RU[spinner_configuring_firewall]="Настройка брандмауэра"
TRANSLATIONS_RU[spinner_auto_updates_already_set]="Автообновления уже настроены"
TRANSLATIONS_RU[spinner_setting_auto_updates]="Настройка автообновлений"
TRANSLATIONS_RU[spinner_downloading_static_files]="Загрузка статических файлов для сайта selfsteal..."

# Config
TRANSLATIONS_RU[config_invalid_arguments]="Ошибка: неверное количество аргументов. Должно быть четное количество ключей и значений."
TRANSLATIONS_RU[config_domain_already_used]="Домен"
TRANSLATIONS_RU[config_domains_must_be_unique]="Каждый домен должен быть уникальным: домен панели, домен подписки и домен selfsteal должны быть разными."
TRANSLATIONS_RU[config_caddy_port_available]="Требуемый порт Caddy 9443 доступен"
TRANSLATIONS_RU[config_caddy_port_in_use]="Требуемый порт Caddy 9443 уже используется!"
TRANSLATIONS_RU[config_node_port_available]="Требуемый порт API ноды 2222 доступен"
TRANSLATIONS_RU[config_node_port_in_use]="Требуемый порт API ноды 2222 уже используется!"
TRANSLATIONS_RU[config_separate_installation_port_required]="Для отдельной установки панели и ноды порт"
TRANSLATIONS_RU[config_free_port_and_retry]="Пожалуйста, освободите порт"
TRANSLATIONS_RU[config_installation_cannot_continue]="Установка не может продолжиться с занятым портом"

# Misc
TRANSLATIONS_RU[misc_qr_generation_failed]="Не удалось создать QR-код"

# Network
TRANSLATIONS_RU[network_error_port_number]="Ошибка: Порт должен быть числом."
TRANSLATIONS_RU[network_error_port_range]="Ошибка: Порт должен быть от 1 до 65535."
TRANSLATIONS_RU[network_invalid_email]="Неверный формат email."
TRANSLATIONS_RU[network_proceed_with_value]="Продолжить с этим значением? Текущее значение:"
TRANSLATIONS_RU[network_using_default_port]="Используется порт по умолчанию:"
TRANSLATIONS_RU[network_port_in_use]="порт уже используется. Поиск доступного порта..."
TRANSLATIONS_RU[network_using_port]="Используется порт:"
TRANSLATIONS_RU[network_failed_find_port]="Не удалось найти доступный порт для"
TRANSLATIONS_RU[network_invalid_domain]="Неверный формат домена. Попробуйте снова."
TRANSLATIONS_RU[network_failed_determine_ip]="Не удалось определить IP-адрес домена или сервера."
TRANSLATIONS_RU[network_make_sure_domain]="Убедитесь, что домен"
TRANSLATIONS_RU[network_points_to_server]="правильно настроен и указывает на сервер"
TRANSLATIONS_RU[network_continue_despite_ip]="Продолжить с этим доменом, несмотря на невозможность проверить его IP-адрес?"
TRANSLATIONS_RU[network_domain_points_cloudflare]="Домен"
TRANSLATIONS_RU[network_points_cloudflare_ip]="указывает на IP Cloudflare"
TRANSLATIONS_RU[network_disable_cloudflare]="Отключите проксирование Cloudflare - проксирование домена selfsteal не разрешено."
TRANSLATIONS_RU[network_continue_despite_cloudflare]="Продолжить с этим доменом, несмотря на проблему с конфигурацией прокси Cloudflare?"
TRANSLATIONS_RU[network_domain_points_server]="Домен"
TRANSLATIONS_RU[network_points_this_server]="указывает на IP этого сервера"
TRANSLATIONS_RU[network_separate_installation_note]="Для отдельной установки домен selfsteal должен указывать на сервер ноды, а не на сервер панели."
TRANSLATIONS_RU[network_continue_despite_current_server]="Продолжить с этим доменом, несмотря на то, что он указывает на текущий сервер?"
TRANSLATIONS_RU[network_domain_points_different]="Домен"
TRANSLATIONS_RU[network_points_different_ip]="указывает на IP-адрес"
TRANSLATIONS_RU[network_differs_from_server]="который отличается от IP сервера"
TRANSLATIONS_RU[network_continue_despite_mismatch]="Продолжить с этим доменом, несмотря на несоответствие IP-адресов?"

# API
TRANSLATIONS_RU[api_empty_server_response]="Пустой ответ сервера"
TRANSLATIONS_RU[api_registration_failed]="Регистрация не удалась: неизвестная ошибка"
TRANSLATIONS_RU[api_failed_get_public_key]="Ошибка: Не удалось получить публичный ключ."
TRANSLATIONS_RU[api_failed_extract_public_key]="Ошибка: Не удалось извлечь публичный ключ из ответа."
TRANSLATIONS_RU[api_empty_response_creating_node]="Ошибка: Пустой ответ от сервера при создании ноды."
TRANSLATIONS_RU[api_failed_create_node]="Ошибка: Не удалось создать ноду, ответ:"
TRANSLATIONS_RU[api_empty_response_getting_inbounds]="Ошибка: Пустой ответ от сервера при получении входящих соединений."
TRANSLATIONS_RU[api_failed_extract_uuid]="Ошибка: Не удалось извлечь UUID из ответа."
TRANSLATIONS_RU[api_empty_response_creating_host]="Ошибка: Пустой ответ от сервера при создании хоста."
TRANSLATIONS_RU[api_failed_create_host]="Ошибка: Не удалось создать хост."
TRANSLATIONS_RU[api_empty_response_creating_user]="Ошибка: Пустой ответ от сервера при создании пользователя."
TRANSLATIONS_RU[api_failed_create_user_status]="Ошибка: Не удалось создать пользователя. HTTP статус:"
TRANSLATIONS_RU[api_failed_create_user_format]="Ошибка: Не удалось создать пользователя, неверный формат ответа:"
TRANSLATIONS_RU[api_failed_register_user]="Не удалось зарегистрировать пользователя."
TRANSLATIONS_RU[api_request_body_was]="Тело запроса было:"
TRANSLATIONS_RU[api_response]="Ответ:"

# Validation
TRANSLATIONS_RU[validation_value_min]="Значение должно быть не менее"
TRANSLATIONS_RU[validation_value_max]="Значение должно быть не более"
TRANSLATIONS_RU[validation_enter_numeric]="Пожалуйста, введите корректное числовое значение."
TRANSLATIONS_RU[validation_input_empty]="Ввод не может быть пустым. Пожалуйста, введите корректный домен или IP-адрес."
TRANSLATIONS_RU[validation_invalid_ip]="Неверный формат IP-адреса. IP должен быть в формате X.X.X.X, где X - число от 0 до 255."
TRANSLATIONS_RU[validation_invalid_domain]="Неверный формат доменного имени. Домен должен содержать хотя бы одну точку и не начинаться/заканчиваться точкой или тире."
TRANSLATIONS_RU[validation_use_only_letters]="Используйте только буквы, цифры, точки и тире."
TRANSLATIONS_RU[validation_invalid_domain_ip]="Неверный формат домена или IP-адреса."
TRANSLATIONS_RU[validation_domain_format]="Домен должен содержать хотя бы одну точку и не начинаться/заканчиваться точкой или тире."
TRANSLATIONS_RU[validation_ip_format]="IP-адрес должен быть в формате X.X.X.X, где X - число от 0 до 255."
TRANSLATIONS_RU[validation_max_attempts_default]="Превышено максимальное количество попыток. Используется значение по умолчанию:"
TRANSLATIONS_RU[validation_max_attempts_no_input]="Превышено максимальное количество попыток. Корректный ввод не предоставлен."
TRANSLATIONS_RU[validation_cannot_continue]="Установка не может продолжиться без корректного домена или IP-адреса."

# VLESS
TRANSLATIONS_RU[vless_failed_generate_keys]="Ошибка: Не удалось сгенерировать ключи."
TRANSLATIONS_RU[vless_empty_response_xray]="Ошибка: Пустой ответ от сервера при обновлении конфигурации Xray."
TRANSLATIONS_RU[vless_failed_update_xray]="Ошибка: Не удалось обновить конфигурацию Xray."

# Node
TRANSLATIONS_RU[node_port_9443_in_use]="Требуемый порт Caddy 9443 уже используется!"
TRANSLATIONS_RU[node_separate_port_9443]="Для отдельной установки ноды порт 9443 должен быть доступен."
TRANSLATIONS_RU[node_free_port_9443]="Пожалуйста, освободите порт 9443 и попробуйте снова."
TRANSLATIONS_RU[node_cannot_continue_9443]="Установка не может продолжиться с занятым портом 9443"
TRANSLATIONS_RU[node_port_2222_in_use]="Требуемый порт API ноды 2222 уже используется!"
TRANSLATIONS_RU[node_separate_port_2222]="Для отдельной установки ноды порт 2222 должен быть доступен."
TRANSLATIONS_RU[node_free_port_2222]="Пожалуйста, освободите порт 2222 и попробуйте снова."
TRANSLATIONS_RU[node_cannot_continue_2222]="Установка не может продолжиться с занятым портом 2222"
TRANSLATIONS_RU[node_enter_ssl_cert]="Введите сертификат сервера в формате SSL_CERT=\"...\" (вставьте содержимое и нажмите Enter дважды):"
TRANSLATIONS_RU[node_ssl_cert_valid]="✓ Формат SSL сертификата корректен"
TRANSLATIONS_RU[node_ssl_cert_invalid]="✗ Неверный формат SSL сертификата. Попробуйте снова."
TRANSLATIONS_RU[node_ssl_cert_expected]="Ожидаемый формат: SSL_CERT=\"...eyJub2RlQ2VydFBldW0iOiAi...\""
TRANSLATIONS_RU[node_port_info]="• Порт ноды:"
TRANSLATIONS_RU[node_directory_info]="• Директория ноды:"

# Container
TRANSLATIONS_RU[container_error_provide_args]="Ошибка: укажите директорию и отображаемое имя"
TRANSLATIONS_RU[container_error_directory_not_found]="Ошибка: директория \"%s\" не найдена"
TRANSLATIONS_RU[container_error_compose_not_found]="Ошибка: docker-compose.yml не найден в \"%s\""
TRANSLATIONS_RU[container_error_docker_not_installed]="Ошибка: Docker не установлен или не находится в PATH"
TRANSLATIONS_RU[container_error_docker_not_running]="Ошибка: Демон Docker не запущен"
TRANSLATIONS_RU[container_rate_limit_error]="✖ Ограничение скорости Docker Hub при загрузке образов для \"%s\"."
TRANSLATIONS_RU[container_rate_limit_cause]="Причина: превышен лимит скорости загрузки."
TRANSLATIONS_RU[container_rate_limit_solutions]="Возможные решения:"
TRANSLATIONS_RU[container_rate_limit_wait]="1. Подождите ~6 ч и повторите попытку"
TRANSLATIONS_RU[container_rate_limit_login]="2. docker login"
TRANSLATIONS_RU[container_rate_limit_vpn]="3. Используйте VPN / другой IP"
TRANSLATIONS_RU[container_rate_limit_mirror]="4. Настройте зеркало"
TRANSLATIONS_RU[container_success_up]="✔ \"%s\" запущен (сервисы: %s)."
TRANSLATIONS_RU[container_failed_start]="✖ \"%s\" не удалось запустить полностью."
TRANSLATIONS_RU[container_compose_output]="→ вывод docker compose:"
TRANSLATIONS_RU[container_problematic_services]="→ Статус проблемных сервисов:"

# General
TRANSLATIONS_RU[exiting]="Выход."
TRANSLATIONS_RU[creating_user]="Создание пользователя:"
TRANSLATIONS_RU[please_wait]="Пожалуйста, подождите..."
TRANSLATIONS_RU[operation_completed]="Операция завершена."

# Node setup
TRANSLATIONS_RU[node_enter_selfsteal_domain]="Введите домен Selfsteal, например domain.example.com"
TRANSLATIONS_RU[node_enter_panel_ip]="Введите IP-адрес сервера панели (для настройки брандмауэра)"
TRANSLATIONS_RU[node_allow_connections]="Разрешение соединений с сервера панели на порт ноды 2222..."
TRANSLATIONS_RU[node_enter_ssl_cert_prompt]="Введите сертификат сервера в формате SSL_CERT=\"...\" (вставьте содержимое и нажмите Enter дважды):"
TRANSLATIONS_RU[node_press_enter_return]="Нажмите Enter для возврата в главное меню..."

# VLESS configuration
TRANSLATIONS_RU[vless_enter_node_host]="Введите IP-адрес или домен сервера ноды (если отличается от домена Selfsteal)"
TRANSLATIONS_RU[vless_public_key_required]="Публичный ключ (требуется для установки ноды):"

# Container names
TRANSLATIONS_RU[container_name_remnawave_panel]="Панель Remnawave"
TRANSLATIONS_RU[container_name_subscription_page]="Страница подписки"
TRANSLATIONS_RU[container_name_remnawave_node]="Нода Remnawave"

# Selfsteal
TRANSLATIONS_RU[selfsteal_installation_stopped]="Установка остановлена"
TRANSLATIONS_RU[selfsteal_domain_info]="• Домен:"
TRANSLATIONS_RU[selfsteal_port_info]="• Порт:"
TRANSLATIONS_RU[selfsteal_directory_info]="• Директория:"
