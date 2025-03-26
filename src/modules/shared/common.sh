#!/bin/bash

# Определение цветов для вывода
BOLD_BLUE=$(tput setaf 4)
BOLD_GREEN=$(tput setaf 2)
LIGHT_GREEN=$(tput setaf 10)
BOLD_BLUE_MENU=$(tput setaf 6)
ORANGE=$(tput setaf 3)
BOLD_RED=$(tput setaf 1)
BLUE=$(tput setaf 6)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
NC=$(tput sgr0)

# Версия скрипта
VERSION="1.0"

# Основные директории
REMNAWAVE_DIR="$HOME/remnawave"
REMNANODE_ROOT_DIR="$HOME/remnanode"
REMNANODE_DIR="$HOME/remnanode/node"
SELFSTEAL_DIR="$HOME/remnanode/selfsteal"
LOCAL_REMNANODE_DIR="$REMNAWAVE_DIR/node" # Директория локальной ноды (вместе с панелью)

# Функция для проверки и удаления предыдущей установки
remove_previous_installation() {
    # Проверка наличия предыдущей установки
    local containers=("remnawave-subscription-page" "remnawave" "remnawave-db" "remnawave-redis" "remnanode" "caddy-remnawave")
    local container_exists=false

    # Проверка существования любого из контейнеров
    for container in "${containers[@]}"; do
        if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -q "$container"; then
            container_exists=true
            break
        fi
    done

    if [ -d "$REMNAWAVE_DIR" ] || [ "$container_exists" = true ]; then
        show_warning "Обнаружена предыдущая установка RemnaWave."
        if prompt_yes_no "Для продолжения требуется удалить предыдущие установки Remnawave. Подтверждаете удаление?" "$ORANGE"; then
            # Проверка наличия Caddy и его остановка
            if [ -f "$REMNAWAVE_DIR/caddy/docker-compose.yml" ]; then
                cd $REMNAWAVE_DIR && docker compose -f caddy/docker-compose.yml down >/dev/null 2>&1 &
                spinner $! "Останавливаем контейнер Caddy"
            fi
            # Проверка наличия страницы подписки и её остановка
            if [ -f "$REMNAWAVE_DIR/subscription-page/docker-compose.yml" ]; then
                cd $REMNAWAVE_DIR && docker compose -f subscription-page/docker-compose.yml down >/dev/null 2>&1 &
                spinner $! "Останавливаем контейнер remnawave-subscription-page"
            fi
            # Проверка наличия ноды и её остановка
            if [ -f "$LOCAL_REMNANODE_DIR/docker-compose.yml" ]; then
                cd $LOCAL_REMNANODE_DIR && docker compose -f panel/docker-compose.yml down >/dev/null 2>&1 &
                spinner $! "Останавливаем контейнер ноды Remnawave"
            fi
            # Проверка наличия панели и её остановка
            if [ -f "$REMNAWAVE_DIR/panel/docker-compose.yml" ]; then
                cd $REMNAWAVE_DIR && docker compose -f panel/docker-compose.yml down >/dev/null 2>&1 &
                spinner $! "Останавливаем контейнеры панели Remnawave"
            fi

            # Проверка наличия оставшихся контейнеров и их остановка
            for container in "${containers[@]}"; do
                if docker ps -a --format '{{.Names}}' | grep -q "^$container$"; then
                    docker stop "$container" >/dev/null 2>&1 && docker rm "$container" >/dev/null 2>&1 &
                    spinner $! "Останавливаем и удаляем контейнер $container"
                fi
            done

            # Удаление директории
            rm -rf $REMNAWAVE_DIR >/dev/null 2>&1 &
            spinner $! "Удаляем каталог $REMNAWAVE_DIR"
            # Удаление томов Docker
            docker volume rm remnawave-db-data remnawave-redis-data >/dev/null 2>&1 &
            spinner $! "Удаляем тома Docker: remnawave-db-data и remnawave-redis-data"
            show_success "Проведено удаление предыдущей установки."
        else
            return 0
        fi
    fi
}

# Отображение сообщения об успешной установке панели
display_panel_installation_complete_message() {
    local secure_panel_url="https://$SCRIPT_PANEL_DOMAIN/auth/login?caddy=$PANEL_SECRET_KEY"
    local effective_width=$((${#secure_panel_url} + 3))
    local border_line=$(printf '─%.0s' $(seq 1 $effective_width))

    print_text_line() {
        local text="$1"
        local padding=$((effective_width - ${#text} - 1))
        echo -e "\033[1m│ $text$(printf '%*s' $padding)│\033[0m"
    }

    print_empty_line() {
        echo -e "\033[1m│$(printf '%*s' $effective_width)│\033[0m"
    }

    echo -e "\033[1m┌${border_line}┐\033[0m"

    print_text_line "Ваш домен для панели:"
    print_text_line "https://$SCRIPT_PANEL_DOMAIN"
    print_empty_line
    print_text_line "Ссылка для безопасного входа (c секретным ключом):"
    print_text_line "$secure_panel_url"
    print_empty_line
    print_text_line "Ваш домен для подписок:"
    print_text_line "https://$SCRIPT_SUB_DOMAIN"
    print_empty_line
    print_text_line "Логин администратора: $SUPERADMIN_USERNAME"
    print_text_line "Пароль администратора: $SUPERADMIN_PASSWORD"
    print_empty_line
    echo -e "\033[1m└${border_line}┘\033[0m"

    echo
    show_success "Данные сохранены в файле: $CREDENTIALS_FILE"
    echo -e "${BOLD_BLUE}Директория установки: ${NC}$REMNAWAVE_DIR/"
    echo

    cd ~

    echo -e "${BOLD_GREEN}Установка завершена. Нажмите Enter, чтобы продолжить...${NC}"
    read -r
}

wait_for_panel() {
    local panel_url="$1"
    local max_wait=180
    local temp_file=$(mktemp)

    # Запускаем проверку доступности сервера в фоновом процессе
    {
        local start_time=$(date +%s)
        local end_time=$((start_time + max_wait))

        while [ $(date +%s) -lt $end_time ]; do
            if curl -s --connect-timeout 1 "http://$panel_url/api/auth/register" >/dev/null; then
                echo "success" >"$temp_file"
                exit 0
            fi
            sleep 1
        done
        echo "timeout" >"$temp_file"
        exit 1
    } &
    local check_pid=$!

    spinner "$check_pid" "Ожидание инициализации панели..."

    if [ "$(cat "$temp_file")" = "success" ]; then
        show_success "Панель готова к работе!"
        rm -f "$temp_file"
        return 0
    else
        show_warning "Превышено максимальное время ожидания ($max_wait секунд)."
        show_info "Пробуем продолжить регистрацию в любом случае..."
        rm -f "$temp_file"
        return 1
    fi
}

register_user() {
    local panel_url="$1"
    local panel_domain="$2"
    local username="$3"
    local password="$4"
    local api_url="http://${panel_url}/api/auth/register"

    local reg_token=""
    local reg_error=""

    local response=$(
        curl -s "$api_url" \
        -H "Host: $panel_domain" \
        -H "X-Forwarded-For: $panel_url" \
        -H "X-Forwarded-Proto: https" \
        -H "Content-Type: application/json" \
        --data-raw '{"username":"'"$username"'","password":"'"$password"'"}'
    )

    if [ -z "$response" ]; then
        reg_error="Пустой ответ сервера"
        return 1
    elif [[ "$response" == *"accessToken"* ]]; then
        # Успешная регистрация
        reg_token=$(echo "$response" | jq -r '.response.accessToken')
        echo "$reg_token"
        return 0
    else
        echo "$response"
        return 1
    fi
}

restart_panel() {
    local no_wait=${1:-false} # Optional parameter to skip waiting for user input
    # Проверка существования директории панели
    if [ ! -d ~/remnawave/panel ]; then
        show_error "Ошибка: директория панели не найдена по пути ~/remnawave/panel!"
        show_error "Сначала установите панель Remnawave."
    else
        # Проверка наличия docker-compose.yml в директории панели
        if [ ! -f ~/remnawave/panel/docker-compose.yml ]; then
            show_error "Ошибка: docker-compose.yml не найден в директории панели!"
            show_error "Возможно, установка панели повреждена или не завершена."
        else
            # Переменная для отслеживания наличия директории subscription-page
            SUBSCRIPTION_PAGE_EXISTS=false

            # Проверка существования директории subscription-page
            if [ -d ~/remnawave/subscription-page ] && [ -f ~/remnawave/subscription-page/docker-compose.yml ]; then
                SUBSCRIPTION_PAGE_EXISTS=true
            fi

            # Останавливаем страницу подписки, если она существует
            if [ "$SUBSCRIPTION_PAGE_EXISTS" = true ]; then
                cd ~/remnawave/subscription-page && docker compose down >/dev/null 2>&1 &
                spinner $! "Останавливаем контейнер remnawave-subscription-page"
            fi

            # Останавливаем панель
            cd ~/remnawave/panel && docker compose down >/dev/null 2>&1 &
            spinner $! "Перезапуск панели..."

            # Запускаем панель
            cd ~/remnawave/panel && docker compose up -d >/dev/null 2>&1 &
            spinner $! "Перезапуск панели..."

            # Запускаем страницу подписки, если она существует
            if [ "$SUBSCRIPTION_PAGE_EXISTS" = true ]; then
                cd ~/remnawave/subscription-page && docker compose up -d >/dev/null 2>&1 &
                spinner $! "Перезапуск панели..."
            fi
            show_info "Панель перезапущена"
        fi
    fi
    if [ "$no_wait" != "true" ]; then
        echo -e "${BOLD_GREEN}Нажмите Enter, чтобы продолжить...${NC}"
        read
    fi
}

start_container() {
    local directory="$1"      # Директория с docker-compose.yml
    local container_name="$2" # Имя контейнера для проверки в docker ps
    local service_name="$3"   # Название сервиса для вывода сообщений
    local wait_time=${4:-1}   # Время ожидания в секундах

    # Переходим в нужную директорию
    cd "$directory"

    # Запускаем весь процесс в фоне с помощью подоболочки
    (
        docker compose up -d >/dev/null 2>&1
        sleep $wait_time
    ) &

    local bg_pid=$!

    # Отображаем спиннер для всего процесса запуска и ожидания
    spinner $bg_pid "Запуск контейнера ${service_name}..."

    # Проверяем статус контейнера
    if ! docker ps | grep -q "$container_name"; then
        echo -e "${BOLD_RED}Контейнер $service_name не запустился. Проверьте конфигурацию.${NC}"
        echo -e "${ORANGE}Вы можете проверить логи позже с помощью 'make logs' в директории $directory.${NC}"
        return 1
    else
        # echo -e "${BOLD_GREEN}$service_name успешно запущен.${NC}"
        # echo ""
        return 0
    fi
}

generate_secure_password() {
    local length="${1:-16}"
    local password=""
    local special_chars='!%^&*_+.,'
    local uppercase_chars='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local lowercase_chars='abcdefghijklmnopqrstuvwxyz'
    local number_chars='0123456789'
    local alphanumeric_chars="${uppercase_chars}${lowercase_chars}${number_chars}"

    # Генерируем начальный пароль только из букв и цифр
    if command -v openssl &>/dev/null; then
        password="$(openssl rand -base64 48 | tr -dc "$alphanumeric_chars" | head -c "$length")"
    else
        # Если openssl недоступен, fallback на /dev/urandom
        password="$(head -c 100 /dev/urandom | tr -dc "$alphanumeric_chars" | head -c "$length")"
    fi

    # Проверяем наличие символов каждого типа и добавляем недостающие
    # Если нет символа верхнего регистра, добавляем его
    if ! [[ "$password" =~ [$uppercase_chars] ]]; then
        local position=$((RANDOM % length))
        local one_uppercase="$(echo "$uppercase_chars" | fold -w1 | shuf | head -n1)"
        password="${password:0:$position}${one_uppercase}${password:$((position + 1))}"
    fi

    # Если нет символа нижнего регистра, добавляем его
    if ! [[ "$password" =~ [$lowercase_chars] ]]; then
        local position=$((RANDOM % length))
        local one_lowercase="$(echo "$lowercase_chars" | fold -w1 | shuf | head -n1)"
        password="${password:0:$position}${one_lowercase}${password:$((position + 1))}"
    fi

    # Если нет цифры, добавляем её
    if ! [[ "$password" =~ [$number_chars] ]]; then
        local position=$((RANDOM % length))
        local one_number="$(echo "$number_chars" | fold -w1 | shuf | head -n1)"
        password="${password:0:$position}${one_number}${password:$((position + 1))}"
    fi

    # Добавляем от 1 до 3 специальных символов (в зависимости от длины пароля)
    # но не более 25% длины пароля
    local special_count=$((length / 4))
    special_count=$((special_count > 0 ? special_count : 1))
    special_count=$((special_count < 3 ? special_count : 3))

    for ((i = 0; i < special_count; i++)); do
        # Выбираем случайную позицию, избегая первого и последнего символа
        local position=$((RANDOM % (length - 2) + 1))
        local one_special="$(echo "$special_chars" | fold -w1 | shuf | head -n1)"
        password="${password:0:$position}${one_special}${password:$((position + 1))}"
    done

    echo "$password"
}

# Функция для безопасного обновления .env файла с несколькими ключами
update_file() {
    local env_file="$1"
    shift

    # Проверка наличия параметров
    if [ "$#" -eq 0 ] || [ $(($# % 2)) -ne 0 ]; then
        echo "Ошибка: неверное количество аргументов. Должно быть чётное число ключей и значений." >&2
        return 1
    fi

    # Преобразуем аргументы в массивы ключей и значений
    local keys=()
    local values=()

    while [ "$#" -gt 0 ]; do
        keys+=("$1")
        values+=("$2")
        shift 2
    done

    # Создаем временный файл
    local temp_file=$(mktemp)

    # Построчно обрабатываем файл и заменяем нужные строки
    while IFS= read -r line || [[ -n "$line" ]]; do
        local key_found=false
        for i in "${!keys[@]}"; do
            if [[ "$line" =~ ^${keys[$i]}= ]]; then
                echo "${keys[$i]}=${values[$i]}" >>"$temp_file"
                key_found=true
                break
            fi
        done

        if [ "$key_found" = false ]; then
            echo "$line" >>"$temp_file"
        fi
    done <"$env_file"

    # Заменяем оригинальный файл
    mv "$temp_file" "$env_file"
}

# Создание общего Makefile для управления сервисами
create_makefile() {
    local directory="$1"
    cat >"$directory/Makefile" <<'EOF'
.PHONY: start stop restart logs

start:
	docker compose up -d && docker compose logs -f -t
stop:
	docker compose down
restart:
	docker compose down && docker compose up -d
logs:
	docker compose logs -f -t
EOF
}

# ===================================================================================
#                                ФУНКЦИИ ВАЛИДАЦИИ
# ===================================================================================

# Функция для валидации и очистки доменного имени или IP-адреса
# Оставляет только допустимые символы: буквы, цифры, точки и дефисы
# Использование:
#   validate_domain "example.com"
validate_domain() {
    local input="$1"
    local max_length="${2:-253}" # Максимальная длина домена по стандарту

    # Проверка на IP-адрес
    if [[ "$input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # Проверка каждого октета IP-адреса
        local valid_ip=true
        IFS='.' read -r -a octets <<<"$input"
        for octet in "${octets[@]}"; do
            if [[ ! "$octet" =~ ^[0-9]+$ ]] || [ "$octet" -gt 255 ]; then
                valid_ip=false
                break
            fi
        done

        if [ "$valid_ip" = true ]; then
            echo "$input"
            return 0
        fi
    fi

    # Удаляем все символы, кроме букв, цифр, точек и дефисов
    local cleaned_domain=$(echo "$input" | tr -cd 'a-zA-Z0-9.-')

    # Проверка на пустую строку после очистки
    if [ -z "$cleaned_domain" ]; then
        echo ""
        return 1
    fi

    # Проверка на максимальную длину
    if [ ${#cleaned_domain} -gt $max_length ]; then
        cleaned_domain=${cleaned_domain:0:$max_length}
    fi

    # Проверка формата домена (простая базовая проверка)
    # Домен должен содержать хотя бы одну точку и не начинаться/заканчиваться точкой или дефисом
    if
        [[ ! "$cleaned_domain" =~ \. ]] ||
            [[ "$cleaned_domain" =~ ^[\.-] ]] ||
            [[ "$cleaned_domain" =~ [\.-]$ ]]
    then
        echo "$cleaned_domain"
        return 1
    fi

    echo "$cleaned_domain"
    return 0
}

# Безопасное чтение пользовательского ввода с валидацией
# Использование:
#   read_domain "Введите домен:" "example.com"
read_domain() {
    local prompt="$1"
    local default_value="$2"
    local max_attempts="${3:-3}"
    local result=""
    local attempts=0

    while [ $attempts -lt $max_attempts ]; do
        # Показываем подсказку с дефолтным значением, если оно есть
        local prompt_formatted_text=""
        if [ -n "$default_value" ]; then
            prompt_formatted_text="${ORANGE}${prompt} [$default_value]:${NC}"
        else
            prompt_formatted_text="${ORANGE}${prompt}:${NC}"
        fi

        read -p "$prompt_formatted_text" input

        # Если ввод пустой и есть дефолтное значение, используем его
        if [ -z "$input" ] && [ -n "$default_value" ]; then
            result="$default_value"
            break
        fi

        # Валидируем ввод
        result=$(validate_domain "$input")
        local status=$?

        if [ $status -eq 0 ]; then
            break
        else
            echo -e "${BOLD_RED}Некорректный формат домена или IP-адреса. Пожалуйста, используйте только буквы, цифры, точки и дефисы.${NC}" >&2
            echo -e "${BOLD_RED}Домен должен содержать как минимум одну точку и не начинаться/заканчиваться точкой или дефисом.${NC}" >&2
            echo -e "${BOLD_RED}IP-адрес должен быть в формате X.X.X.X, где X - число от 0 до 255.${NC}" >&2
            ((attempts++))
        fi
    done

    if [ $attempts -eq $max_attempts ]; then
        echo -e "${BOLD_RED}Превышено максимальное количество попыток. Используется значение по умолчанию: $default_value${NC}" >&2
        result="$default_value"
    fi

    echo "$result"
}

# Функция для валидации и очистки порта
# Оставляет только числовые символы и проверяет, что значение в диапазоне 1-65535
# Использование:
#   validate_port "8080"
validate_port() {
    local input="$1"
    local default_port="$2"

    # Удаляем все символы, кроме цифр
    local cleaned_port=$(echo "$input" | tr -cd '0-9')

    # Проверка на пустую строку после очистки
    if [ -z "$cleaned_port" ] && [ -n "$default_port" ]; then
        echo "$default_port"
        return 0
    elif [ -z "$cleaned_port" ]; then
        echo ""
        return 1
    fi

    # Проверка на диапазон портов
    if [ "$cleaned_port" -lt 1 ] || [ "$cleaned_port" -gt 65535 ]; then
        if [ -n "$default_port" ]; then
            echo "$default_port"
            return 0
        else
            echo ""
            return 1
        fi
    fi

    echo "$cleaned_port"
    return 0
}

# Проверка, свободен ли порт
is_port_available() {
    local port=$1
    # Пытаемся запустить временный сервер на порту
    # Если возвращает 0, порт свободен, если 1 - занят
    (echo >/dev/tcp/localhost/$port) >/dev/null 2>&1
    if [ $? -eq 1 ]; then
        return 0 # Порт свободен
    else
        return 1 # Порт занят
    fi
}

# Нахождение свободного порта, начиная с указанного
find_available_port() {
    local port="$1"

    # Пробуем последовательно, пока не найдём свободный
    while true; do
        if is_port_available "$port"; then
            show_info_e "Порт $port доступен."
            echo "$port"
            return 0
        fi
        ((port++))
        # На всякий случай, ограничимся 65535
        if [ "$port" -gt 65535 ]; then
            show_info_e "Не удалось найти свободный порт!"
            return 1
        fi
    done
}

# Функция безопасного чтения порта с валидацией
# Использование:
#   read_port "Введите порт:" "8080"
#   read_port "Введите порт:" "8080" true    # Пропустить проверку доступности порта
read_port() {
    local prompt="$1"
    local default_value="${2:-}"
    local skip_availability_check="${3:-false}"
    local result=""
    local attempts=0
    local max_attempts=3

    while [ $attempts -lt $max_attempts ]; do
        # Отображение приглашения с дефолтным значением
        if [ -n "$default_value" ]; then
            prompt_formatted_text="${ORANGE}${prompt} [$default_value]:${NC}"
            read -p "$prompt_formatted_text" result
        else
            prompt_formatted_text="${ORANGE}${prompt}:${NC}"
            read -p "$prompt_formatted_text" result
        fi

        # Если ввод пустой и есть дефолтное значение, используем его
        if [ -z "$result" ] && [ -n "$default_value" ]; then
            result="$default_value"
        fi

        # Валидация порта - сохраняем результат в переменную
        result=$(validate_port "$result")
        local status=$?

        if [ $status -eq 0 ]; then
            # Проверяем, свободен ли порт (если проверка не отключена)
            if [ "$skip_availability_check" = true ] || is_port_available "$result"; then
                break
            else
                show_info_e "Порт ${result} уже занят."
                prompt_formatted_text="${ORANGE}Хотите автоматически найти свободный порт? [y/N]:${NC}"
                read -p "$prompt_formatted_text" answer
                if [[ "$answer" =~ ^[yY] ]]; then
                    result="$(find_available_port "$result")"
                    break
                else
                    show_info_e "Пожалуйста, выберите другой порт."
                    ((attempts++))
                fi
            fi
        else
            # В зависимости от кода возврата выводим сообщение
            case $status in
            1) show_info_e "Некорректный ввод (не число). Пожалуйста, введите корректный порт." ;;
            2) show_info_e "Некорректный порт. Введите число от 1 до 65535." ;;
            esac
            ((attempts++))
        fi
    done

    if [ $attempts -eq $max_attempts ]; then
        show_info_e "Превышено максимальное количество попыток. Используем порт по умолчанию."
        if [ -n "$default_value" ]; then
            result="$default_value"
            if [ "$skip_availability_check" = false ] && ! is_port_available "$result"; then
                result="$(find_available_port "$result")"
            fi
        else
            # Если нет дефолтного значения, используем случайный свободный порт
            local random_start=$((RANDOM % 10000 + 10000))
            result="$(find_available_port "$random_start")"
        fi
    fi

    # Здесь ОДИН раз выводим результат
    echo "$result"
}

generate_readable_login() {
    # Согласные и гласные буквы для более читаемых комбинаций
    consonants="bcdfghjklmnpqrstvwxz"
    vowels="aeiouy"

    # Случайная длина от 6 до 10 символов
    length=$((6 + RANDOM % 5))

    # Инициализация пустой строки для логина
    login=""

    # Генерация логина, чередуя согласные и гласные
    for ((i = 0; i < length; i++)); do
        if ((i % 2 == 0)); then
            # Выбираем случайную согласную
            rand_index=$((RANDOM % ${#consonants}))
            login="${login}${consonants:rand_index:1}"
        else
            # Выбираем случайную гласную
            rand_index=$((RANDOM % ${#vowels}))
            login="${login}${vowels:rand_index:1}"
        fi
    done

    echo "$login"
}

# Функция для проверки, указывает ли домен на текущий сервер
check_domain_points_to_server() {
    local domain="$1"
    local show_warning="${2:-true}" # По умолчанию показывать предупреждение

    # Получаем IP домена
    local domain_ip=""
    domain_ip=$(dig +short "$domain" | grep -v ";" | head -n 1)

    # Получаем публичный IP текущего сервера
    local server_ip=""
    server_ip=$(curl -s -4 ifconfig.me || curl -s -4 api.ipify.org || curl -s -4 ipinfo.io/ip)

    # Если не смогли получить IP, выходим
    if [ -z "$domain_ip" ] || [ -z "$server_ip" ]; then
        if [ "$show_warning" = true ]; then
            show_warning "Не удалось определить IP-адрес домена или сервера."
            show_warning "Убедитесь, что домен $domain правильно настроен и указывает на этот сервер ($server_ip)."
        fi
        return 1
    fi

    # Сравниваем IP
    if [ "$domain_ip" != "$server_ip" ]; then
        if [ "$show_warning" = true ]; then
            show_warning "Домен $domain указывает на IP-адрес $domain_ip, который отличается от IP-адреса этого сервера ($server_ip)."
            show_warning "Для корректной работы необходимо, чтобы домен указывал на текущий сервер."
            if prompt_yes_no "Продолжить установку несмотря на неверную конфигурацию домена?" "$ORANGE"; then
                return 1
            else
                return 2 # Код 2 означает, что пользователь решил прервать установку
            fi
        fi
        return 1
    fi

    return 0 # Успешная проверка
}
