#!/bin/bash

# Remnawave Installer 

# Включение модуля: common.sh

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
REMNAWAVE_DIR="/opt/remnawave"
REMNANODE_ROOT_DIR="/opt/remnanode"
REMNANODE_DIR="/opt/remnanode/node"
SELFSTEAL_DIR="/opt/remnanode/selfsteal"
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

            # Удаление оставшихся образов Docker
            docker rmi $(docker images -q) -f >/dev/null 2>&1 &
            spinner $! "Удаляем образы Docker"

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
    if [ ! -d /opt/remnawave/panel ]; then
        show_error "Ошибка: директория панели не найдена по пути /opt/remnawave/panel!"
        show_error "Сначала установите панель Remnawave."
    else
        # Проверка наличия docker-compose.yml в директории панели
        if [ ! -f /opt/remnawave/panel/docker-compose.yml ]; then
            show_error "Ошибка: docker-compose.yml не найден в директории панели!"
            show_error "Возможно, установка панели повреждена или не завершена."
        else
            # Переменная для отслеживания наличия директории subscription-page
            SUBSCRIPTION_PAGE_EXISTS=false

            # Проверка существования директории subscription-page
            if [ -d /opt/remnawave/subscription-page ] && [ -f /opt/remnawave/subscription-page/docker-compose.yml ]; then
                SUBSCRIPTION_PAGE_EXISTS=true
            fi

            # Останавливаем страницу подписки, если она существует
            if [ "$SUBSCRIPTION_PAGE_EXISTS" = true ]; then
                cd /opt/remnawave/subscription-page && docker compose down >/dev/null 2>&1 &
                spinner $! "Останавливаем контейнер remnawave-subscription-page"
            fi

            # Останавливаем панель
            cd /opt/remnawave/panel && docker compose down >/dev/null 2>&1 &
            spinner $! "Перезапуск панели..."

            # Запускаем панель
            cd /opt/remnawave/panel && docker compose up -d >/dev/null 2>&1 &
            spinner $! "Перезапуск панели..."

            # Запускаем страницу подписки, если она существует
            if [ "$SUBSCRIPTION_PAGE_EXISTS" = true ]; then
                cd /opt/remnawave/subscription-page && docker compose up -d >/dev/null 2>&1 &
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
#                                API REQUEST ФУНКЦИИ
# ===================================================================================

# Функция для выполнения API запроса с Bearer токеном
# Параметры:
#   $1 - метод (GET, POST, PUT, DELETE)
#   $2 - полный URL
#   $3 - Bearer токен для авторизации
#   $4 - домен хоста (для заголовка Host)
#   $5 - данные запроса в формате JSON (опционально, только для POST/PUT)
make_api_request() {
    local method=$1
    local url=$2
    local token=$3
    local panel_domain=$4
    local data=$5

    local headers=(
        -H "Authorization: Bearer $token"
        -H "Content-Type: application/json"
        -H "Host: $panel_domain"
        -H "X-Forwarded-For: ${url#http://}"
        -H "X-Forwarded-Proto: https"
    )

    if [ -n "$data" ]; then
        curl -s -X "$method" "$url" "${headers[@]}" -d "$data"
    else
        curl -s -X "$method" "$url" "${headers[@]}"
    fi
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

# ===================================================================================
#                                VLESS КОНФИГУРАЦИЯ
# ===================================================================================

# Генерация ключей для VLESS Reality
generate_vless_keys() {
  local temp_file=$(mktemp)
  
  # Генерация ключей x25519 с помощью Docker
  docker run --rm ghcr.io/xtls/xray-core x25519 >"$temp_file" 2>&1 &
  spinner $! "Генерация ключей x25519..."
  keys=$(cat "$temp_file")
  
  local private_key=$(echo "$keys" | grep "Private key:" | awk '{print $3}')
  local public_key=$(echo "$keys" | grep "Public key:" | awk '{print $3}')
  rm -f "$temp_file"

  if [ -z "$private_key" ] || [ -z "$public_key" ]; then
    echo -e "${BOLD_RED}Ошибка: Не удалось сгенерировать ключи.${NC}"
    return 1
  fi
  
  # Возвращаем ключи через echo
  echo "$private_key:$public_key"
}

# Создание VLESS конфигурации Xray
generate_vless_config() {
  local config_file="$1"
  local self_steal_domain="$2"
  local self_steal_port="$3"
  local private_key="$4"
  local public_key="$5"
  
  local short_id=$(openssl rand -hex 8)
  
  cat >"$config_file" <<EOL
{
  "log": {
    "loglevel": "debug"
  },
  "inbounds": [
    {
      "tag": "VLESS TCP REALITY",
      "port": 443,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "127.0.0.1:$self_steal_port",
          "show": false,
          "xver": 1,
          "shortIds": [
            "$short_id"
          ],
          "publicKey": "$public_key",
          "privateKey": "$private_key",
          "serverNames": [
              "$self_steal_domain"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "DIRECT",
      "protocol": "freedom"
    },
    {
      "tag": "BLOCK",
      "protocol": "blackhole"
    }
  ],
  "routing": {
    "rules": [
      {
        "ip": [
          "geoip:private"
        ],
        "type": "field",
        "outboundTag": "BLOCK"
      },
      {
        "type": "field",
        "domain": [
          "geosite:private"
        ],
        "outboundTag": "BLOCK"
      },
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "BLOCK"
      }
    ]
  }
}
EOL
}

# Обновление конфигурации Xray
update_xray_config() {
  local panel_url="$1"
  local token="$2"
  local panel_domain="$3"
  local config_file="$4"
  
  local temp_file=$(mktemp)
  local new_config=$(cat "$config_file")
  
  make_api_request "POST" "http://$panel_url/api/xray/update-config" "$token" "$panel_domain" "$new_config" > "$temp_file" 2>&1 &
  spinner $! "Обновление конфигурации Xray..."
  local update_response=$(cat "$temp_file")
  rm -f "$temp_file"

  if [ -z "$update_response" ]; then
    echo -e "${BOLD_RED}Ошибка: Пустой ответ от сервера при обновлении Xray конфига.${NC}"
    return 1
  fi

  if echo "$update_response" | jq -e '.response.config' >/dev/null; then
    return 0
  else
    echo -e "${BOLD_RED}Ошибка: Не удалось обновить конфигурацию Xray.${NC}"
    return 1
  fi
}

# Создание ноды
create_vless_node() {
  local panel_url="$1"
  local token="$2"
  local panel_domain="$3"
  local node_host="$4"
  local node_port="$5"
  
  local node_name="VLESS-NODE"
  local temp_file=$(mktemp)
  
  local new_node_data=$(
    cat <<EOF
{
    "name": "$node_name",
    "address": "$node_host",
    "port": $node_port,
    "isTrafficTrackingActive": false,
    "trafficLimitBytes": 0,
    "notifyPercent": 0,
    "trafficResetDay": 31,
    "excludedInbounds": [],
    "countryCode": "XX",
    "consumptionMultiplier": 1.0
}
EOF
  )
  
  make_api_request "POST" "http://$panel_url/api/nodes/create" "$token" "$panel_domain" "$new_node_data" > "$temp_file" 2>&1 &
  spinner $! "Создание ноды..."
  node_response=$(cat "$temp_file")
  rm -f "$temp_file"

  if [ -z "$node_response" ]; then
    echo -e "${BOLD_RED}Ошибка: Пустой ответ от сервера при создании ноды.${NC}"
    return 1
  fi

  if echo "$node_response" | jq -e '.response.uuid' >/dev/null; then
    return 0
  else
    echo -e "${BOLD_RED}Ошибка: Не удалось создать ноду, ответ:${NC}"
    echo
    echo "Был направлен запрос с телом:"
    echo "$new_node_data"
    echo
    echo "Ответ:"
    echo
    echo "$node_response"
    return 1
  fi
}

# Получение списка inbounds
get_inbounds() {
  local panel_url="$1"
  local token="$2"
  local panel_domain="$3"
  
  local temp_file=$(mktemp)
  
  make_api_request "GET" "http://$panel_url/api/inbounds" "$token" "$panel_domain" > "$temp_file" 2>&1 &
  spinner $! "Получение списка inbounds..."
  inbounds_response=$(cat "$temp_file")
  rm -f "$temp_file"

  if [ -z "$inbounds_response" ]; then
    echo -e "${BOLD_RED}Ошибка: Пустой ответ от сервера при получении inbounds.${NC}"
    return 1
  fi

  local inbound_uuid=$(echo "$inbounds_response" | jq -r '.response[0].uuid')
  if [ -z "$inbound_uuid" ]; then
    echo -e "${BOLD_RED}Ошибка: Не удалось извлечь UUID из ответа.${NC}"
    return 1
  fi
  
  # Возвращаем UUID
  echo "$inbound_uuid"
}

# Создание хоста
create_vless_host() {
  local panel_url="$1"
  local token="$2"
  local panel_domain="$3"
  local inbound_uuid="$4"
  local self_steal_domain="$5"
  
  local temp_file=$(mktemp)
  
  local host_data=$(
    cat <<EOF
{
    "inboundUuid": "$inbound_uuid",
    "remark": "VLESS TCP REALITY",
    "address": "$self_steal_domain",
    "port": 443,
    "path": "",
    "sni": "$self_steal_domain",
    "host": "$self_steal_domain",
    "alpn": "h2",
    "fingerprint": "chrome",
    "allowInsecure": false,
    "isDisabled": false
}
EOF
  )

  make_api_request "POST" "http://$panel_url/api/hosts/create" "$token" "$panel_domain" "$host_data" > "$temp_file" 2>&1 &
  spinner $! "Создание хоста для UUID: $inbound_uuid..."
  host_response=$(cat "$temp_file")
  rm -f "$temp_file"

  if [ -z "$host_response" ]; then
    echo -e "${BOLD_RED}Ошибка: Пустой ответ от сервера при создании хоста.${NC}"
    return 1
  fi

  if echo "$host_response" | jq -e '.response.uuid' >/dev/null; then
    return 0
  else
    echo -e "${BOLD_RED}Ошибка: Не удалось создать хост.${NC}"
    return 1
  fi
}

# Получение публичного ключа API
get_public_key() {
  local panel_url="$1"
  local token="$2"
  local panel_domain="$3"
  
  local temp_file=$(mktemp)
  
  make_api_request "GET" "http://$panel_url/api/keygen/get" "$token" "$panel_domain" > "$temp_file" 2>&1 &
  spinner $! "Получение публичного ключа..."
  api_response=$(cat "$temp_file")
  rm -f "$temp_file"

  if [ -z "$api_response" ]; then
    echo -e "${BOLD_RED}Ошибка: Не удалось получить публичный ключ.${NC}"
    return 1
  fi

  local pubkey=$(echo "$api_response" | jq -r '.response.pubKey')
  if [ -z "$pubkey" ]; then
    echo -e "${BOLD_RED}Ошибка: Не удалось извлечь публичный ключ из ответа.${NC}"
    return 1
  fi
  
  # Возвращаем публичный ключ
  echo "$pubkey"
}

# Функция проверки, находится ли IP в одном из CIDR-диапазонов (Cloudflare или любом другом, передаваемом в виде массива)
is_ip_in_cidrs() {
    local ip="$1"
    shift
    local cidrs=("$@")

    # Вспомогательная функция перевода IP (формат x.x.x.x) в 32-битное число
    function ip2dec() {
        local a b c d
        IFS=. read -r a b c d <<<"$1"
        echo $(((a << 24) + (b << 16) + (c << 8) + d))
    }

    # Функция проверки, лежит ли IP в CIDR
    function in_cidr() {
        local ip_dec mask base_ip cidr_ip cidr_mask
        ip_dec=$(ip2dec "$1")
        base_ip="${2%/*}"
        mask="${2#*/}"

        cidr_ip=$(ip2dec "$base_ip")
        cidr_mask=$((0xFFFFFFFF << (32 - mask) & 0xFFFFFFFF))

        # Если (ip_dec & cidr_mask) == (cidr_ip & cidr_mask), IP попадает в диапазон
        if (((ip_dec & cidr_mask) == (cidr_ip & cidr_mask))); then
            return 0
        else
            return 1
        fi
    }

    # Проверяем IP по всем диапазонам, если подходит под хотя бы один, возвращаем 0
    for range in "${cidrs[@]}"; do
        if in_cidr "$ip" "$range"; then
            return 0
        fi
    done

    return 1
}

# Функция для проверки, указывает ли домен на текущий сервер
check_domain_points_to_server() {
    local domain="$1"
    local show_warning="${2:-true}"   # По умолчанию показывать предупреждение
    local allow_cf_proxy="${3:-true}" # По умолчанию разрешать проксирование Cloudflare

    # Получаем IP домена
    local domain_ip=""
    domain_ip=$(dig +short A "$domain" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)

    # Получаем публичный IP текущего сервера
    local server_ip=""
    server_ip=$(curl -s -4 ifconfig.me || curl -s -4 api.ipify.org || curl -s -4 ipinfo.io/ip)

    # Если не смогли получить IP, выходим
    if [ -z "$domain_ip" ] || [ -z "$server_ip" ]; then
        if [ "$show_warning" = true ]; then
            show_warning "Не удалось определить IP-адрес домена или сервера."
            show_warning "Убедитесь, что домен $domain правильно настроен и указывает на сервер ($server_ip)."
        fi
        return 1
    fi

    # Загружаем актуальные Cloudflare диапазоны
    local cf_ranges
    cf_ranges=$(curl -s https://www.cloudflare.com/ips-v4) || true # если curl не сработал, переменная останется пустой

    # Если смогли загрузить, превращаем в массив
    local cf_array=()
    if [ -n "$cf_ranges" ]; then
        # Превращаем полученные строки в массив
        IFS=$'\n' read -r -d '' -a cf_array <<<"$cf_ranges"
    fi

    # Проверяем, входит ли domain_ip в диапазоны Cloudflare
    if [ ${#cf_array[@]} -gt 0 ] && is_ip_in_cidrs "$domain_ip" "${cf_array[@]}"; then
        # IP Cloudflare
        if [ "$allow_cf_proxy" = true ]; then
            # Разрешено проксирование — всё ок
            return 0
        else
            # Проксирование запрещено — предупреждаем
            if [ "$show_warning" = true ]; then
                echo ""
                show_warning "Домен $domain указывает на IP Cloudflare ($domain_ip)."
                show_warning "Отключите проксирование Cloudflare - недопустимо проксирование selfsteal домена"
                if prompt_yes_no "Продолжить установку несмотря на неверную конфигурацию домена?" "$ORANGE"; then
                    return 1
                else
                    return 2
                fi
            fi
            return 1
        fi
    else
        # Если не Cloudflare, проверяем, совпадает ли IP домена с IP сервера
        if [ "$domain_ip" != "$server_ip" ]; then
            if [ "$show_warning" = true ]; then
                echo ""
                show_warning "Домен $domain указывает на IP-адрес $domain_ip, который отличается от IP-адреса сервера ($server_ip)."
                show_warning "Для корректной работы необходимо, чтобы домен указывал на текущий сервер."
                if prompt_yes_no "Продолжить установку несмотря на неверную конфигурацию домена?" "$ORANGE"; then
                    return 1
                else
                    return 2
                fi
            fi
            return 1
        fi
    fi

    return 0 # Всё корректно
}

# Включение модуля: ui.sh
draw_info_box() {
    local title="$1"
    local subtitle="$2"

    # Фиксированная ширина блока для идеального выравнивания
    local width=54

    echo -e "${BOLD_GREEN}"
    # Верхняя граница
    printf "┌%s┐\n" "$(printf '─%.0s' $(seq 1 $width))"

    # Центрирование заголовка
    local title_padding_left=$(((width - ${#title}) / 2))
    local title_padding_right=$((width - title_padding_left - ${#title}))
    printf "│%*s%s%*s│\n" "$title_padding_left" "" "$title" "$title_padding_right" ""

    # Центрирование подзаголовка
    local subtitle_padding_left=$(((width - ${#subtitle}) / 2))
    local subtitle_padding_right=$((width - subtitle_padding_left - ${#subtitle}))
    printf "│%*s%s%*s│\n" "$subtitle_padding_left" "" "$subtitle" "$subtitle_padding_right" ""

    # Пустая строка
    printf "│%*s│\n" "$width" ""

    # Строка версии - аккуратная обработка цветов
    local version_text="  • Версия: "
    local version_value="$VERSION"
    local version_value_colored="${ORANGE}${version_value}${BOLD_GREEN}"
    local version_value_length=${#version_value}
    local remaining_space=$((width - ${#version_text} - version_value_length))
    printf "│%s%s%*s│\n" "$version_text" "$version_value_colored" "$remaining_space" ""

    # Пустая строка
    printf "│%*s│\n" "$width" ""

    # Нижняя граница
    printf "└%s┘\n" "$(printf '─%.0s' $(seq 1 $width))"
    echo -e "${NC}"
}

# Очистка экрана
clear_screen() {
    clear
}

# Отображение заголовка раздела
draw_section_header() {
    local title="$1"
    local width=${2:-50}
    
    echo -e "${BOLD_RED}\033[1m┌$(printf '─%.0s' $(seq 1 $width))┐\033[0m${NC}"
    
    # Центрирование заголовка
    local padding_left=$(((width - ${#title}) / 2))
    local padding_right=$((width - padding_left - ${#title}))
    echo -e "${BOLD_RED}\033[1m│$(printf ' %.0s' $(seq 1 $padding_left))$title$(printf ' %.0s' $(seq 1 $padding_right))│\033[0m${NC}"
    
    echo -e "${BOLD_RED}\033[1m└$(printf '─%.0s' $(seq 1 $width))┘\033[0m${NC}"
    echo
}

# Отображение опций меню с нумерацией
draw_menu_options() {
    local options=("$@")
    local idx=1
    
    for option in "${options[@]}"; do
        echo -e "${ORANGE}$idx. $option${NC}"
        ((idx++))
    done
    echo
}

# Запрос ввода с предустановленным текстом и цветом
prompt_input() {
    local prompt_text="$1"
    local prompt_color="${2:-$GREEN}"
    
    echo -ne "${prompt_color}${prompt_text}${NC}" >&2
    read input_value
    echo >&2
    
    echo "$input_value"
}

# Запрос ввода пароля (с отключением эхо)
prompt_password() {
    local prompt_text="$1"
    local prompt_color="${2:-$ORANGE}"
    
    echo -ne "${prompt_color}${prompt_text}${NC}" >&2
    stty -echo
    read password_value
    stty echo
    echo >&2
    
    echo "$password_value"
}

# Запрос выбора опции (y/n)
prompt_yes_no() {
    local prompt_text="$1"
    local prompt_color="${2:-$GREEN}"
    local default="${3:-}"
    
    local prompt_suffix=" (y/n): "
    [ -n "$default" ] && prompt_suffix=" (y/n) [$default]: "
    
    echo -ne "${prompt_color}${prompt_text}${prompt_suffix}${NC}" >&2
    read answer
    echo >&2
    
    # Преобразование в нижний регистр
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
    
    # Если пусто, используем значение по умолчанию
    [ -z "$answer" ] && answer="$default"
    
    if [ "$answer" = "y" ] || [ "$answer" = "yes" ]; then
        return 0
    else
        return 1
    fi
}

# Выбор опции из нумерованного меню
prompt_menu_option() {
    local prompt_text="$1"
    local prompt_color="${2:-$GREEN}"
    local min="${3:-1}"
    local max="$4"
    
    local selected_option
    while true; do
        echo -ne "${prompt_color}${prompt_text} (${min}-${max}): ${NC}" >&2
        read selected_option
        echo >&2
        
        # Валидация выбора
        if [[ "$selected_option" =~ ^[0-9]+$ ]] && \
           [ "$selected_option" -ge "$min" ] && \
           [ "$selected_option" -le "$max" ]; then
            break
        else
            echo -e "${BOLD_RED}Пожалуйста, введите число от ${min} до ${max}.${NC}" >&2
        fi
    done
    
    echo "$selected_option"
}

show_success() {
    local message="$1"
    echo -e "${BOLD_GREEN}✓ ${message}${NC}"
    echo ""
}

show_error() {
    local message="$1"
    echo -e "${BOLD_RED}✗ ${message}${NC}"
    echo ""
}

show_warning() {
    local message="$1"
    echo -e "${BOLD_YELLOW}⚠  ${message}${NC}"
    echo ""
}

show_info() {
    local message="$1"
    local color="${2:-$ORANGE}"
    echo -e "${color}${message}${NC}"
    echo ""
}

show_info_e() {
    local message="$1"
    local color="${2:-$ORANGE}"
    echo -e "${color}${message}${NC}" >&2
    echo "" >&2
}

# Отображение разделителя
draw_separator() {
    local width=${1:-50}
    local char=${2:-"-"}
    
    printf "%s\n" "$(printf "$char%.0s" $(seq 1 $width))"
}

# Отображение прогресса операции
show_progress() {
    local message="$1"
    local progress_char=${2:-"."}
    local count=${3:-3}
    
    echo -ne "${message}"
    for ((i=0; i<count; i++)); do
        echo -ne "${progress_char}"
        sleep 0.5
    done
    echo ""
}

# Запрос домена с валидацией
prompt_domain() {
    local prompt_text="$1"
    local prompt_color="${2:-$ORANGE}"
    
    local domain
    while true; do
        echo -ne "${prompt_color}${prompt_text}: ${NC}" >&2
        read domain
        echo >&2
        
        # Базовая валидация домена (может быть расширена)
        if [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
            break
        else
            echo -e "${BOLD_RED}Неверный формат домена. Пожалуйста, попробуйте снова.${NC}" >&2
        fi
    done
    
    echo "$domain"
    echo ""
}

# Запрос числового значения с валидацией
prompt_number() {
    local prompt_text="$1"
    local prompt_color="${2:-$ORANGE}"
    local min="${3:-1}"
    local max="${4:-}"
    
    local number
    while true; do
        echo -ne "${prompt_color}${prompt_text}: ${NC}" >&2
        read number
        echo >&2
        
        # Валидация числа
        if [[ "$number" =~ ^[0-9]+$ ]]; then
            if [ -n "$min" ] && [ "$number" -lt "$min" ]; then
                echo -e "${BOLD_RED}Значение должно быть не меньше ${min}.${NC}" >&2
                continue
            fi
            
            if [ -n "$max" ] && [ "$number" -gt "$max" ]; then
                echo -e "${BOLD_RED}Значение должно быть не больше ${max}.${NC}" >&2
                continue
            fi
            
            break
        else
            echo -e "${BOLD_RED}Пожалуйста, введите корректное числовое значение.${NC}" >&2
        fi
    done
    
    echo "$number"
}

# Отображение ряда с заголовком и значением
draw_info_row() {
    local label="$1"
    local value="$2"
    local label_color="${3:-$ORANGE}"
    local value_color="${4:-$GREEN}"
    local width=${5:-50}
    
    local label_display="${label_color}${label}:${NC}"
    local value_display="${value_color}${value}${NC}"
    
    echo -e "${label_display} ${value_display}"
}

# Центрирование текста
center_text() {
    local text="$1"
    local width=${2:-$(tput cols)}
    local padding_left=$(((width - ${#text}) / 2))
    
    printf "%${padding_left}s%s\n" "" "$text"
}

# Отображение блока с завершающим сообщением
draw_completion_message() {
    local title="$1"
    local message="$2"
    local width=${3:-70}
    
    draw_separator "$width" "="
    center_text "$title" "$width"
    echo
    echo -e "$message"
    draw_separator "$width" "="
}

# Валидация пароля на сложность
validate_password_strength() {
    local password="$1"
    local min_length=${2:-8}
    
    local length=${#password}
    
    # Проверка длины
    if [ "$length" -lt "$min_length" ]; then
        echo "Пароль должен содержать не менее $min_length символов."
        return 1
    fi
    
    # Проверка наличия цифр
    if ! [[ "$password" =~ [0-9] ]]; then
        echo "Пароль должен содержать хотя бы одну цифру."
        return 1
    fi
    
    # Проверка наличия букв нижнего регистра
    if ! [[ "$password" =~ [a-z] ]]; then
        echo "Пароль должен содержать хотя бы одну букву нижнего регистра."
        return 1
    fi
    
    # Проверка наличия букв верхнего регистра
    if ! [[ "$password" =~ [A-Z] ]]; then
        echo "Пароль должен содержать хотя бы одну букву верхнего регистра."
        return 1
    fi
    
    # Пароль прошел все проверки
    return 0
}

# Запрос пароля с подтверждением и проверкой сложности
prompt_secure_password() {
    local prompt_text="$1"
    local confirm_text="${2:-Повторно введите пароль для подтверждения}"
    local min_length=${3:-8}
    
    local password1 password2 error_message
    
    while true; do
        # Запрашиваем пароль
        password1=$(prompt_password "$prompt_text")
        
        # Проверяем сложность пароля
        error_message=$(validate_password_strength "$password1" "$min_length")
        if [ $? -ne 0 ]; then
            echo -e "${BOLD_RED}${error_message} Пожалуйста, попробуйте снова.${NC}" >&2
            continue
        fi
        
        # Запрашиваем подтверждение пароля
        password2=$(prompt_password "$confirm_text")
        
        # Проверяем совпадение паролей
        if [ "$password1" = "$password2" ]; then
            break
        else
            echo -e "${BOLD_RED}Пароли не совпадают. Пожалуйста, попробуйте снова.${NC}" >&2
        fi
    done
    
    echo "$password1"
}

# Функция для отображения спиннера во время выполнения команды
spinner() {
    local pid=$1
    local text=$2
    local spinstr='⣷⣯⣟⡿⢿⣻⣽⣾'
    local text_code="$BOLD_GREEN"
    local bg_code=""
    local effect_code="\033[1m"
    local delay=0.12
    local reset_code="$NC"

    printf "${effect_code}${text_code}${bg_code}%s${reset_code}" "$text" >/dev/tty

    while kill -0 "$pid" 2>/dev/null; do
        for ((i = 0; i < ${#spinstr}; i++)); do
            printf "\r${effect_code}${text_code}${bg_code}[%s] %s${reset_code}" "$(echo -n "${spinstr:$i:1}")" "$text" >/dev/tty
            sleep $delay
        done
    done

    printf "\r\033[K" >/dev/tty
}

# Включение модуля: tools.sh

enable_bbr() {
  # Проверка существования настроек BBR в sysctl.conf
  if grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf && grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo ""
    show_warning "BBR уже добавлен в /etc/sysctl.conf"
    # Проверка, активен ли BBR сейчас
    local current_cc=$(sysctl -n net.ipv4.tcp_congestion_control)
    local current_qdisc=$(sysctl -n net.core.default_qdisc)
    if [[ "$current_cc" == "bbr" && "$current_qdisc" == "fq" ]]; then
      show_info "BBR активен и работает"
    else
      show_info "BBR настроен в конфигурации, но не активен. Применяю настройки..."
      sysctl -p
    fi
    show_info "Нажмите Enter, чтобы продолжить"
    read -r
  else
    # Установка BBR если не найден
    echo "net.core.default_qdisc=fq" >>/etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >>/etc/sysctl.conf
    # Применение изменений
    sysctl -p
    show_info "BBR успешно включен. Нажмите Enter, чтобы продолжить"
    read -r
  fi
}

# Включение модуля: dependencies.sh

# Функция для проверки и установки зависимостей
check_and_install_dependency() {
    local packages=("$@")
    local failed=false

    for package_name in "${packages[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$package_name" 2>/dev/null | grep -q "install ok installed"; then
            show_info "Установка пакета $package_name..."
            sudo apt-get install -y "$package_name" >/dev/null 2>&1

            if ! dpkg-query -W -f='${Status}' "$package_name" 2>/dev/null | grep -q "install ok installed"; then
                show_error "Ошибка: Не удалось установить $package_name. Установите его вручную."
                show_error "Для работы скрипта требуется пакет $package_name."
                sleep 2
                failed=true
            else
                show_info "Пакет $package_name успешно установлен."
            fi
        fi
    done

    if [ "$failed" = true ]; then
        return 1
    fi
    return 0
}

# Установка общих зависимостей для всех компонентов
install_dependencies() {
    show_info "Проверка зависимостей..."
    # Ставим lsb-release, если его нет – он потребуется, чтобы определить дистрибутив
    if ! command -v lsb_release &>/dev/null; then
        sudo apt-get update >/dev/null 2>&1
        sudo apt-get install -y lsb-release >/dev/null 2>&1
    fi

    # Теперь обновляем пакеты после установки lsb-release

    sudo apt-get update >/dev/null 2>&1

    # Проверка и установка необходимых пакетов
    check_and_install_dependency "curl" "jq" "make" "dnsutils" || {
        show_error "Ошибка: Не все необходимые зависимости были установлены."
        return 1
    }

    # Проверка, установлен ли Docker
    if command -v docker &>/dev/null && docker --version &>/dev/null; then
        return 0
    else
        sudo apt-get remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc >/dev/null 2>&1
        show_info "Установка Docker и других необходимых пакетов..."

        # Установка предварительных зависимостей
        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common >/dev/null 2>&1

        # Создание директории для хранения ключей
        sudo mkdir -p /etc/apt/keyrings

        # Добавление официального GPG-ключа Docker
        # Путь к файлу-ключу – /etc/apt/keyrings/docker.gpg
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg 2>/dev/null ||
            {
                # Если не удалось, пробуем удалить файл и добавить ключ снова
                sudo rm -f /etc/apt/keyrings/docker.gpg
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
                    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
            }

        # Настройка прав доступа к ключу
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        # Определяем дистрибутив и репозиторий
        DIST_ID=$(lsb_release -is | tr '[:upper:]' '[:lower:]') # ubuntu или debian
        CODENAME=$(lsb_release -cs)                             # jammy, focal, bookworm и т.д.

        if [ "$DIST_ID" = "ubuntu" ]; then
            REPO_URL="https://download.docker.com/linux/ubuntu"
        elif [ "$DIST_ID" = "debian" ]; then
            REPO_URL="https://download.docker.com/linux/debian"
        else
            show_error "Неподдерживаемый дистрибутив: $DIST_ID"
            exit 1
        fi

        # Добавление репозитория Docker
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $REPO_URL $CODENAME stable" |
            sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

        # Обновление индексного списка пакетов
        sudo apt-get update >/dev/null 2>&1

        # Установка Docker Engine, Docker CLI, containerd, плагинов Buildx и Compose
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1

        # Проверка наличия группы docker и создание, если она не существует
        if ! getent group docker >/dev/null; then
            show_info "Создание группы docker..."
            sudo groupadd docker
        fi

        # Добавление текущего пользователя в группу docker (чтобы использовать Docker без sudo)
        sudo usermod -aG docker "$USER"

        # Проверка успешности установки
        if command -v docker &>/dev/null; then
            echo -e "${GREEN}Docker успешно установлен: $(docker --version)${NC}"
        else
            echo -e "${RED}Ошибка установки Docker${NC}"
            exit 1
        fi
    fi
}

# Включение модуля: remnawave-subscription-page.sh

# Установка и настройка remnawave-subscription-page
setup_remnawave-subscription-page() {
    # echo -e "${BOLD_GREEN}Установка remnawave-subscription-page...${NC}"

    # Создаем директорию для remnawave-subscription-page
    mkdir -p $REMNAWAVE_DIR/subscription-page

    cd $REMNAWAVE_DIR/subscription-page

    # Создание .env файла
    cat >.env <<EOF
PANEL_DOMAIN=$SCRIPT_PANEL_DOMAIN
EOF

    # Создание docker-compose.yml для remnawave-subscription-page
    cat >docker-compose.yml <<"EOF"
services:
    remnawave-subscription-page:
        image: remnawave/subscription-page:latest
        container_name: remnawave-subscription-page
        hostname: remnawave-subscription-page
        restart: always
        env_file:
            - .env
        environment:
            - REMNAWAVE_PLAIN_DOMAIN=${PANEL_DOMAIN}
            - SUBSCRIPTION_PAGE_PORT=3010
        ports:
            - '127.0.0.1:3010:3010'
        networks:
            - remnawave-network

networks:
    remnawave-network:
        driver: bridge
        external: true
EOF

    # Создание Makefile для remnawave-subscription-page
    create_makefile "$REMNAWAVE_DIR/subscription-page"

    # echo -e "${BOLD_GREEN}Конфигурация remnawave-subscription-page завершена.${NC}"
}

# Включение модуля: caddy.sh

# Настройка Caddy для панели Remnawave
setup_caddy_for_panel() {
    local PANEL_SECRET_KEY=$1
    
    cd $REMNAWAVE_DIR/caddy

    # Определение SUB_BACKEND_URL в зависимости от установки remnawave-subscription-page
    if [ "$INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE" = "y" ] || [ "$INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE" = "yes" ]; then
        SCRIPT_SUB_BACKEND_URL="127.0.0.1:3010"
        REWRITE_RULE=""
    else
        SCRIPT_SUB_BACKEND_URL="127.0.0.1:3000"
        REWRITE_RULE="rewrite * /api/sub{uri}"
    fi

    # Создание .env файла для Caddy
    cat >.env <<EOF
PANEL_DOMAIN=$SCRIPT_PANEL_DOMAIN
PANEL_PORT=443
SUB_DOMAIN=$SCRIPT_SUB_DOMAIN
SUB_PORT=443
BACKEND_URL=127.0.0.1:3000
SUB_BACKEND_URL=$SCRIPT_SUB_BACKEND_URL
PANEL_SECRET_KEY=$PANEL_SECRET_KEY
EOF

    PANEL_DOMAIN='$PANEL_DOMAIN'
    PANEL_PORT='$PANEL_PORT'
    BACKEND_URL='$BACKEND_URL'
    PANEL_SECRET_KEY='$PANEL_SECRET_KEY'

    SUB_DOMAIN='$SUB_DOMAIN'
    SUB_PORT='$SUB_PORT'
    SUB_BACKEND_URL='$SUB_BACKEND_URL'

    # Создание Caddyfile с защитой панели
    cat >Caddyfile <<EOF
{$PANEL_DOMAIN}:{$PANEL_PORT} {
        @has_token_param {
                query caddy={$PANEL_SECRET_KEY}
        }
        handle @has_token_param {
                header +Set-Cookie "caddy={$PANEL_SECRET_KEY}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=31536000"
        }

        @subscription_info_path {
                path_regexp ^/api/sub/[^/]+
        }

        handle @subscription_info_path {
                reverse_proxy {$BACKEND_URL} {
                        @notfound status 404

                        handle_response @notfound {
                                respond 404
                        }

                        header_up X-Real-IP {remote}
                        header_up Host {host}
                }
        }
        @unauthorized {
                not header Cookie *caddy={$PANEL_SECRET_KEY}*
                not query caddy={$PANEL_SECRET_KEY}
                path /
        }
        handle @unauthorized {
                respond 200 {
                        body ""
                        close
                }
        }

        @unauthorized_non_root {
                not header Cookie *caddy={$PANEL_SECRET_KEY}*
                not query caddy={$PANEL_SECRET_KEY}
                path_regexp .+
        }
        handle @unauthorized_non_root {
                respond 404
        }

        reverse_proxy {$BACKEND_URL} {
                header_up X-Real-IP {remote}
                header_up Host {host}
        }
}

{$SUB_DOMAIN}:{$SUB_PORT} {
        handle {
                $REWRITE_RULE
                
                reverse_proxy {$SUB_BACKEND_URL} {
                        header_up X-Real-IP {remote}
                        header_up Host {host}
                        @error status 400 404 422 500
                        handle_response @error {
                                error "" 404
                        }
                }
        }
}
EOF

    # Создание docker-compose.yml для Caddy
    cat >docker-compose.yml <<'EOF'
services:
  caddy:
    image: caddy:2.9.1
    container_name: caddy-remnawave
    restart: always
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./logs:/var/log/caddy
      - caddy_data_panel:/data
      - caddy_config_panel:/config
    env_file:
      - .env
    network_mode: "host"
volumes:
  caddy_data_panel:
  caddy_config_panel:
EOF

    # Создание Makefile
    create_makefile "$REMNAWAVE_DIR/caddy"

    # Создание директории для логов
    mkdir -p $REMNAWAVE_DIR/caddy/logs
}

# Включение модуля: vless-configuration.sh

vless_configuration() {
  local panel_url="$1"
  local panel_domain="$2"
  local token="$3"
  local api_url="http://${panel_url}/api/auth/register"

  # Запрос домена Selfsteal с валидацией
  SELF_STEAL_DOMAIN=$(read_domain "Введите Selfsteal домен, например domain.example.com")
  if [ -z "$SELF_STEAL_DOMAIN" ]; then
    return 1
  fi

  # Запрос порта Selfsteal с валидацией и дефолтным значением
  SELF_STEAL_PORT=$(read_port "Введите Selfsteal порт (можно оставить по умолчанию)" "9443" true)

  # Запрос IP адреса или домена сервера с нодой с валидацией и дефолтным значением Selfsteal домена
  NODE_HOST=$(read_domain "Введите IP адрес или домен сервера с нодой (если отличается от Selfsteal домена)" "$SELF_STEAL_DOMAIN")

  # Запрос порта API ноды с валидацией и дефолтным значением
  NODE_PORT=$(read_port "Введите порт API ноды (можно оставить по умолчанию)" "2222" true)
  
  local config_file="$REMNAWAVE_DIR/panel/config.json"
  
  # Генерация ключей x25519
  local keys_result=$(generate_vless_keys)
  if [ $? -ne 0 ]; then
    return 1
  fi
  
  local private_key=$(echo "$keys_result" | cut -d':' -f1)
  local public_key=$(echo "$keys_result" | cut -d':' -f2)
  
  # Создание конфигурации
  generate_vless_config "$config_file" "$SELF_STEAL_DOMAIN" "$SELF_STEAL_PORT" "$private_key" "$public_key"
  
  # Обновление конфигурации Xray
  if ! update_xray_config "$panel_url" "$token" "$panel_domain" "$config_file"; then
    return 1
  fi
  
  # Создание ноды
  if ! create_vless_node "$panel_url" "$token" "$panel_domain" "$NODE_HOST" "$NODE_PORT"; then
    return 1
  fi
  
  # Получение inbound_uuid
  local inbound_uuid=$(get_inbounds "$panel_url" "$token" "$panel_domain")
  if [ -z "$inbound_uuid" ]; then
    return 1
  fi
  
  # Создание хоста
  if ! create_vless_host "$panel_url" "$token" "$panel_domain" "$inbound_uuid" "$SELF_STEAL_DOMAIN"; then
    return 1
  fi
  
  # Получение публичного ключа
  local pubkey=$(get_public_key "$panel_url" "$token" "$panel_domain")
  if [ -z "$pubkey" ]; then
    return 1
  fi

  echo
  echo -e "${GREEN}Публичный ключ (нужен для установки ноды):${NC}"
  echo
  echo -e "SSL_CERT=\"$pubkey\""
  echo
}

# Включение модуля: panel.sh

# ===================================================================================
#                              УСТАНОВКА ПАНЕЛИ REMNAWAVE
# ===================================================================================

install_panel() {
    clear_screen

    remove_previous_installation

    # Установка общих зависимостей
    install_dependencies

    # Создаем базовую директорию для всего проекта
    mkdir -p $REMNAWAVE_DIR/{panel,caddy}

    # Переходим в директорию панели
    cd $REMNAWAVE_DIR/panel

    # Генерация JWT секретов с помощью openssl
    JWT_AUTH_SECRET=$(openssl rand -hex 32 | tr -d '\n')
    JWT_API_TOKENS_SECRET=$(openssl rand -hex 32 | tr -d '\n')

    # Генерация безопасных учетных данных
    DB_USER="remnawave_$(openssl rand -hex 4 | tr -d '\n')"
    DB_PASSWORD=$(generate_secure_password 16)
    DB_NAME="remnawave_db"
    METRICS_PASS=$(generate_secure_password 16)

    curl -s -o .env https://raw.githubusercontent.com/remnawave/backend/refs/heads/dev/.env.sample

    # Спрашиваем, нужна ли интеграция с Telegram
    if prompt_yes_no "Хотите включить интеграцию с Telegram?"; then
        IS_TELEGRAM_ENV_VALUE="true"
        # Если интеграция с Telegram включена, запрашиваем параметры
        TELEGRAM_BOT_TOKEN=$(prompt_input "Введите токен вашего Telegram бота: " "$ORANGE")
        TELEGRAM_ADMIN_ID=$(prompt_input "Введите ID администратора Telegram: " "$ORANGE")
        NODES_NOTIFY_CHAT_ID=$(prompt_input "Введите ID чата для уведомлений: " "$ORANGE")
    else
        # Если интеграция с Telegram не включена, устанавливаем параметры в "change-me"
        IS_TELEGRAM_ENV_VALUE="false"
        show_warning "Пропуск интеграции с Telegram."
        TELEGRAM_BOT_TOKEN="change-me"
        TELEGRAM_ADMIN_ID="change-me"
        NODES_NOTIFY_CHAT_ID="change-me"
    fi

    # Запрашиваем основной домен для панели с валидацией
    SCRIPT_PANEL_DOMAIN=$(prompt_domain "Введите основной домен для вашей панели (например, panel.example.com)")
    check_domain_points_to_server "$SCRIPT_PANEL_DOMAIN"
    domain_check_result=$?
    if [ $domain_check_result -eq 2 ]; then
        # Пользователь решил прервать установку
        return 1
    fi

    # Запрашиваем домен для подписок с валидацией
    SCRIPT_SUB_DOMAIN=$(prompt_domain "Введите домен для подписок (например, subs.example.com)")
    check_domain_points_to_server "$SCRIPT_SUB_DOMAIN"
    domain_check_result=$?
    if [ $domain_check_result -eq 2 ]; then
        # Пользователь решил прервать установку
        return 1
    fi

    # Запрос на установку remnawave-subscription-page
    if prompt_yes_no "Установить remnawave-subscription-page (https://remna.st/subscription-templating/installation)?"; then
        INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE="y"
    else
        INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE="n"
    fi

    SUPERADMIN_USERNAME=$(generate_readable_login)
    SUPERADMIN_PASSWORD=$(generate_secure_password 25)

    update_file ".env" \
    "JWT_AUTH_SECRET" "$JWT_AUTH_SECRET" \
    "JWT_API_TOKENS_SECRET" "$JWT_API_TOKENS_SECRET" \
    "IS_TELEGRAM_ENABLED" "$IS_TELEGRAM_ENV_VALUE" \
    "TELEGRAM_BOT_TOKEN" "$TELEGRAM_BOT_TOKEN" \
    "TELEGRAM_ADMIN_ID" "$TELEGRAM_ADMIN_ID" \
    "NODES_NOTIFY_CHAT_ID" "$NODES_NOTIFY_CHAT_ID" \
    "SUB_PUBLIC_DOMAIN" "$SCRIPT_SUB_DOMAIN" \
    "DATABASE_URL" "postgresql://$DB_USER:$DB_PASSWORD@remnawave-db:5432/$DB_NAME" \
    "POSTGRES_USER" "$DB_USER" \
    "POSTGRES_PASSWORD" "$DB_PASSWORD" \
    "POSTGRES_DB" "$DB_NAME" \
    "METRICS_PASS" "$METRICS_PASS"

    # Генерация секретного ключа для защиты панели управления
    PANEL_SECRET_KEY=$(openssl rand -hex 16)

    # Создаем docker-compose.yml для панели
    curl -s -o docker-compose.yml https://raw.githubusercontent.com/remnawave/backend/refs/heads/main/docker-compose-prod.yml

    # Меняем образ на dev
    # sed -i "s|image: remnawave/backend:latest|image: remnawave/backend:dev|" docker-compose.yml

    # Создаем Makefile
    create_makefile "$REMNAWAVE_DIR/panel"

    # ===================================================================================
    # Установка remnawave-subscription-page
    # ===================================================================================

    # Установка remnawave-subscription-page, если пользователь согласился
    if [ "$INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE" = "y" ] || [ "$INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE" = "yes" ]; then
        setup_remnawave-subscription-page
    fi

    # ===================================================================================
    # Установка Caddy для панели и подписок
    # ===================================================================================

    setup_caddy_for_panel "$PANEL_SECRET_KEY"

    # Запуск всех контейнеров
    show_info "Запуск контейнеров..." "$BOLD_GREEN"

    # Запуск панели RemnaWave
    start_container "$REMNAWAVE_DIR/panel" "remnawave/backend" "Remnawave"

    # Запуск Caddy
    start_container "$REMNAWAVE_DIR/caddy" "caddy-remnawave" "Caddy"

    # Запуск remnawave-subscription-page (если был выбран)
    if [ "$INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE" = "y" ] || [ "$INSTALL_REMNAWAVE_SUBSCRIPTION_PAGE" = "yes" ]; then
        start_container "$REMNAWAVE_DIR/subscription-page" "remnawave/subscription-page" "Subscription page"
    fi

    wait_for_panel "127.0.0.1:3000"

    REG_TOKEN=$(register_user "127.0.0.1:3000" "$SCRIPT_PANEL_DOMAIN" "$SUPERADMIN_USERNAME" "$SUPERADMIN_PASSWORD")

    if [ -n "$REG_TOKEN" ]; then
        vless_configuration "127.0.0.1:3000" "$SCRIPT_PANEL_DOMAIN" "$REG_TOKEN"
    else
        show_error "Не удалось зарегистрировать пользователя."
    fi

    # Сохранение учетных данных в файл
    CREDENTIALS_FILE="$REMNAWAVE_DIR/panel/credentials.txt"
    echo "PANEL DOMAIN: $SCRIPT_PANEL_DOMAIN" >>"$CREDENTIALS_FILE"
    echo "PANEL URL: https://$SCRIPT_PANEL_DOMAIN?caddy=$PANEL_SECRET_KEY" >>"$CREDENTIALS_FILE"
    echo "" >>"$CREDENTIALS_FILE"
    echo "SUPERADMIN USERNAME: $SUPERADMIN_USERNAME" >>"$CREDENTIALS_FILE"
    echo "SUPERADMIN PASSWORD: $SUPERADMIN_PASSWORD" >>"$CREDENTIALS_FILE"
    echo "" >>"$CREDENTIALS_FILE"
    echo "SECRET KEY: $PANEL_SECRET_KEY" >>"$CREDENTIALS_FILE"

    # Установка безопасных прав на файл с учетными данными
    chmod 600 "$CREDENTIALS_FILE"

    display_panel_installation_complete_message
}

# Включение модуля: selfsteal.sh

# ===================================================================================
#                              УСТАНОВКА STEAL ONESELF САЙТА
# ===================================================================================

setup_selfsteal() {
    mkdir -p $SELFSTEAL_DIR/html && cd $SELFSTEAL_DIR
    
    # Создаем .env файл
    cat > .env << EOF
# Домены
SELF_STEAL_DOMAIN=$SELF_STEAL_DOMAIN
SELF_STEAL_PORT=$SELF_STEAL_PORT
EOF
    
    # Создаем Caddyfile
    cat > Caddyfile << 'EOF'
{
    https_port {$SELF_STEAL_PORT}
    default_bind 127.0.0.1
    servers {
        listener_wrappers {
            proxy_protocol {
                allow 127.0.0.1/32
            }
            tls
        }
    }
    auto_https disable_redirects
}

http://{$SELF_STEAL_DOMAIN} {
    bind 0.0.0.0
    redir https://{$SELF_STEAL_DOMAIN}{uri} permanent
}

https://{$SELF_STEAL_DOMAIN} {
    root * /var/www/html
    try_files {path} /index.html
    file_server
}


:{$SELF_STEAL_PORT} {
    tls internal
    respond 204
}

:80 {
    bind 0.0.0.0
    respond 204
}
EOF
    
    # Создаем docker-compose.yml
    cat > docker-compose.yml << EOF
services:
  caddy:
    image: caddy:2.9.1
    container_name: caddy-selfsteal
    restart: unless-stopped
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./html:/var/www/html
      - ./logs:/var/log/caddy
      - caddy_data_selfsteal:/data
      - caddy_config_selfsteal:/config
    env_file:
      - .env
    network_mode: "host"

volumes:
  caddy_data_selfsteal:
  caddy_config_selfsteal:
EOF
    
    # Создание Makefile для управления
    create_makefile "$SELFSTEAL_DIR"
    
    mkdir -p ./html/assets
    
    # Запускаем процесс скачивания файлов в фоне с перенаправлением вывода
    (
        # Скачивание index.html
        curl -s -o ./html/index.html https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/index.html
        
        # Скачивание файлов assets
        curl -s -o ./html/assets/index-BilmB03J.css https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/index-BilmB03J.css
        curl -s -o ./html/assets/index-CRT2NuFx.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/index-CRT2NuFx.js
        curl -s -o ./html/assets/index-legacy-D44yECni.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/index-legacy-D44yECni.js
        curl -s -o ./html/assets/polyfills-legacy-B97CwC2N.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/polyfills-legacy-B97CwC2N.js
        curl -s -o ./html/assets/vendor-DHVSyNSs.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/vendor-DHVSyNSs.js
        curl -s -o ./html/assets/vendor-legacy-Cq-AagHX.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/vendor-legacy-Cq-AagHX.js
    ) >/dev/null 2>&1 &
    
    download_pid=$!
    
    # Запускаем спиннер для процесса скачивания
    spinner $download_pid "Скачивание статических файлов selfsteal сайта..."
    
    # Запуск сервиса
    mkdir -p logs
    
    start_container "$SELFSTEAL_DIR" "caddy-selfsteal" "Caddy"
    
    # Проверяем, запущен ли сервис
    CADDY_STATUS=$(docker compose ps --services --filter "status=running" | grep -q "caddy" && echo "running" || echo "stopped")
    
    if [ "$CADDY_STATUS" = "running" ]; then
        echo -e "${BOLD_GREEN}✓ Caddy для сайта-заглушки успешно установлен и запущен!${NC}"
        echo -e "${LIGHT_GREEN}• Домен: ${BOLD_GREEN}$SELF_STEAL_DOMAIN${NC}"
        echo -e "${LIGHT_GREEN}• Порт: ${BOLD_GREEN}$SELF_STEAL_PORT${NC}"
        echo -e "${LIGHT_GREEN}• Директория: ${BOLD_GREEN}$SELFSTEAL_DIR${NC}"
        echo ""
    fi
    
    unset SELF_STEAL_DOMAIN
    unset SELF_STEAL_PORT
}

# Включение модуля: node.sh

# ===================================================================================
#                              УСТАНОВКА НОДЫ REMNAWAVE
# ===================================================================================

setup_node() {
    clear

    # Проверка наличия предыдущей установки
    if [ -d "$REMNANODE_ROOT_DIR" ]; then
        show_warning "Обнаружена предыдущая установка Remnawave Node."
        if prompt_yes_no "Для продолжения требуется удалить предыдущую установку, подтверждаете удаление?" "$ORANGE"; then
            # Остановка основного контейнера
            if [ -f "$REMNANODE_DIR/docker-compose.yml" ]; then
                cd $REMNANODE_DIR && docker compose -f docker-compose.yml down >/dev/null 2>&1 &
                spinner $! "Останавливаем контейнер Remnawave Node"
            fi

            # Остановка контейнера selfsteal
            if [ -f "$SELFSTEAL_DIR/docker-compose.yml" ]; then
                cd $SELFSTEAL_DIR && docker compose -f docker-compose.yml down >/dev/null 2>&1 &
                spinner $! "Останавливаем контейнер Selfsteal"
            fi

            # Удаление директории
            rm -rf $REMNANODE_ROOT_DIR >/dev/null 2>&1 &
            spinner $! "Удаляем каталог $REMNANODE_ROOT_DIR"

            show_success "Проведено удаление предыдущей установки."
        else
            return 0
        fi
    fi

    # Установка общих зависимостей
    install_dependencies

    mkdir -p $REMNANODE_DIR && cd $REMNANODE_DIR
    # Создание docker-compose.yml
    cat >docker-compose.yml <<EOL
services:
  remnanode:
    container_name: remnanode
    hostname: remnanode
    image: remnawave/node:latest
    env_file:
      - .env
    network_mode: host
    restart: always
EOL

    # Создание Makefile для ноды
    create_makefile "$REMNANODE_DIR"

    # Запрос домена Selfsteal с валидацией
    SELF_STEAL_DOMAIN=$(read_domain "Введите Selfsteal домен, например domain.example.com")
    if [ -z "$SELF_STEAL_DOMAIN" ]; then
        return 1
    fi

    check_domain_points_to_server "$SELF_STEAL_DOMAIN" true false
    domain_check_result=$?
    if [ $domain_check_result -eq 2 ]; then
        # Пользователь решил прервать установку
        return 1
    fi

    # Запрос порта Selfsteal с валидацией и дефолтным значением
    SELF_STEAL_PORT=$(read_port "Введите Selfsteal порт (можно оставить по умолчанию)" "9443")

    # Запрос порта API ноды с валидацией и дефолтным значением
    NODE_PORT=$(read_port "Введите порт API ноды (можно оставить по умолчанию)" "2222")

    echo -e "${ORANGE}Введите сертификат сервера, НЕ удаляя SSL_CERT= (вставьте содержимое и 2 раза нажмите Enter): ${NC}"
    CERTIFICATE=""
    while IFS= read -r line; do
        if [ -z "$line" ]; then
            if [ -n "$CERTIFICATE" ]; then
                break
            fi
        else
            CERTIFICATE="$CERTIFICATE$line\n"
        fi
    done

    echo -ne "${BOLD_RED}Вы уверены, что сертификат правильный? (y/n): ${NC}"
    read confirm
    echo

    echo -e "### APP ###\nAPP_PORT=$NODE_PORT\n$CERTIFICATE" >.env

    setup_selfsteal

    start_container "$REMNANODE_DIR" "remnawave/node" "Remnawave Node"

    unset CERTIFICATE

    # Проверяем, запущена ли нода
    NODE_STATUS=$(docker compose ps --services --filter "status=running" | grep -q "node" && echo "running" || echo "stopped")

    if [ "$NODE_STATUS" = "running" ]; then
        echo -e "${BOLD_GREEN}✓ Нода Remnawave успешно установлена и запущена!${NC}"
        echo -e "${LIGHT_GREEN}• Порт ноды: ${BOLD_GREEN}$NODE_PORT${NC}"
        echo -e "${LIGHT_GREEN}• Директория ноды: ${BOLD_GREEN}$REMNANODE_DIR${NC}"
        echo ""
    fi

    unset NODE_PORT

    echo -e "\n${BOLD_GREEN}Нажмите Enter, чтобы вернуться в главное меню...${NC}"
    read -r

}

# Включение модуля: setup-node-all-in-one.sh

# ===================================================================================
#                              УСТАНОВКА НОДЫ REMNAWAVE
# ===================================================================================

setup_node_all_in_one() {
    local SCRIPT_SUB_DOMAIN=$1
    local SELF_STEAL_PORT=$2
    local panel_url=$3
    local token=$4
    local NODE_PORT=$5

    mkdir -p "$LOCAL_REMNANODE_DIR" && cd "$LOCAL_REMNANODE_DIR"
    
    # Создание docker-compose.yml
    cat > docker-compose.yml << EOL
services:
  remnanode:
    container_name: remnanode
    hostname: remnanode
    image: remnawave/node:latest
    env_file:
      - .env
    network_mode: host
    restart: always
EOL

    # Создание Makefile для ноды
    create_makefile "$LOCAL_REMNANODE_DIR"

    # Получение публичного ключа
    local temp_file=$(mktemp)
    make_api_request "GET" "http://$panel_url/api/keygen/get" "$token" "$SCRIPT_SUB_DOMAIN" > "$temp_file" 2>&1 &
    spinner $! "Получение публичного ключа..."
    api_response=$(cat "$temp_file")
    rm -f "$temp_file"

    if [ -z "$api_response" ]; then
        echo -e "${BOLD_RED}Ошибка: Не удалось получить публичный ключ.${NC}"
        return 1
    fi

    pubkey=$(echo "$api_response" | jq -r '.response.pubKey')
    if [ -z "$pubkey" ]; then
        echo -e "${BOLD_RED}Ошибка: Не удалось извлечь публичный ключ из ответа.${NC}"
        return 1
    fi

    local CERTIFICATE="SSL_CERT=\"$pubkey\""

    echo -e "### APP ###\nAPP_PORT=$NODE_PORT\n$CERTIFICATE" >.env
}

# Включение модуля: setup-caddy-all-in-one.sh

# Настройка Caddy для панели Remnawave
setup_caddy_all_in_one() {
	local PANEL_SECRET_KEY=$1
	local SCRIPT_SUB_DOMAIN=$2
	local SELF_STEAL_PORT=$3

	cd $REMNAWAVE_DIR/caddy

	SCRIPT_SUB_BACKEND_URL="127.0.0.1:3000"
	local REWRITE_RULE="rewrite * /api{uri}"

	# Создание .env файла для Caddy
	cat >.env <<EOF
SCRIPT_SUB_DOMAIN=$SCRIPT_SUB_DOMAIN
PORT=$SELF_STEAL_PORT
PANEL_SECRET_KEY=$PANEL_SECRET_KEY
SUB_BACKEND_URL=$SCRIPT_SUB_BACKEND_URL
BACKEND_URL=127.0.0.1:3000
EOF

	SCRIPT_SUB_DOMAIN='$SCRIPT_SUB_DOMAIN'
	PORT='$PORT'
	BACKEND_URL='$BACKEND_URL'
	SUB_BACKEND_URL='$SUB_BACKEND_URL'
	PANEL_SECRET_KEY='$PANEL_SECRET_KEY'

	# Создание Caddyfile
	cat >Caddyfile <<EOF
{
	https_port {$PORT}
	default_bind 127.0.0.1
	servers {
		listener_wrappers {
			proxy_protocol {
				allow 127.0.0.1/32
			}
			tls
		}
	}
	auto_https disable_redirects
}

http://{$SCRIPT_SUB_DOMAIN} {
	bind 0.0.0.0
	redir https://{$SCRIPT_SUB_DOMAIN}{uri} permanent
}

https://{$SCRIPT_SUB_DOMAIN} {
	@has_token_param {
		query caddy={$PANEL_SECRET_KEY}
	}
	handle @has_token_param {
		header +Set-Cookie "caddy={$PANEL_SECRET_KEY}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=31536000"
	}

	handle_path /sub/* {
		handle {
			rewrite * /api/sub{uri}
			reverse_proxy {$BACKEND_URL} {
				@notfound status 404

				handle_response @notfound {
					root * /var/www/html
					try_files {path} /index.html
					file_server
				}
				header_up X-Real-IP {remote}
				header_up Host {host}
			}
		}
	}

	@unauthorized {
		not header Cookie *caddy={$PANEL_SECRET_KEY}*
		not query caddy={$PANEL_SECRET_KEY}
	}

	handle @unauthorized {
		root * /var/www/html
		try_files {path} /index.html
		file_server
	}

	reverse_proxy {$BACKEND_URL} {
		header_up X-Real-IP {remote}
		header_up Host {host}
	}
}

:{$PORT} {
	tls internal
	respond 204
}

:80 {
	bind 0.0.0.0
	respond 204
}
EOF

	# Создание docker-compose.yml для Caddy
	cat >docker-compose.yml <<'EOF'
services:
  caddy:
    image: caddy:2.9.1
    container_name: caddy-remnawave
    restart: unless-stopped
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./html:/var/www/html
      - ./logs:/var/log/caddy
      - caddy_data_panel:/data
      - caddy_config_panel:/config
    env_file:
      - .env
    network_mode: "host"
volumes:
  caddy_data_panel:
  caddy_config_panel:
EOF

	# Создание Makefile
	create_makefile "$REMNAWAVE_DIR/caddy"

	# Создание директории для логов
	mkdir -p $REMNAWAVE_DIR/caddy/logs

	mkdir -p $REMNAWAVE_DIR/caddy/html/assets

	# Запускаем процесс скачивания файлов в фоне с перенаправлением вывода
	(
		# Скачивание index.html
		curl -s -o ./html/index.html https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/index.html

		# Скачивание файлов assets
		curl -s -o ./html/assets/index-BilmB03J.css https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/index-BilmB03J.css
		curl -s -o ./html/assets/index-CRT2NuFx.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/index-CRT2NuFx.js
		curl -s -o ./html/assets/index-legacy-D44yECni.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/index-legacy-D44yECni.js
		curl -s -o ./html/assets/polyfills-legacy-B97CwC2N.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/polyfills-legacy-B97CwC2N.js
		curl -s -o ./html/assets/vendor-DHVSyNSs.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/vendor-DHVSyNSs.js
		curl -s -o ./html/assets/vendor-legacy-Cq-AagHX.js https://raw.githubusercontent.com/xxphantom/caddy-for-remnawave/refs/heads/main/html/assets/vendor-legacy-Cq-AagHX.js
	) >/dev/null 2>&1 &

	download_pid=$!
}

# Включение модуля: vless-configuration-all-in-one.sh

vless_configuration_all_in_one() {
  local panel_url="$1"
  local panel_domain="$2"
  local token="$3"
  local SELF_STEAL_PORT="$4"
  local NODE_PORT="$5"
  local config_file="$REMNAWAVE_DIR/panel/config.json"

  # В режиме all-in-one мы используем локальный host IP для ноды
  NODE_HOST="172.17.0.1"

  # Генерация ключей
  local keys_result=$(generate_vless_keys)
  if [ $? -ne 0 ]; then
    return 1
  fi

  local private_key=$(echo "$keys_result" | cut -d':' -f1)
  local public_key=$(echo "$keys_result" | cut -d':' -f2)

  # Создание конфигурации
  generate_vless_config "$config_file" "$panel_domain" "$SELF_STEAL_PORT" "$private_key" "$public_key"

  # Обновление конфигурации Xray
  if ! update_xray_config "$panel_url" "$token" "$panel_domain" "$config_file"; then
    return 1
  fi

  # Создание ноды
  if ! create_vless_node "$panel_url" "$token" "$panel_domain" "$NODE_HOST" "$NODE_PORT"; then
    return 1
  fi

  # Получение inbound_uuid
  local inbound_uuid=$(get_inbounds "$panel_url" "$token" "$panel_domain")
  if [ -z "$inbound_uuid" ]; then
    return 1
  fi

  # Создание хоста
  if ! create_vless_host "$panel_url" "$token" "$panel_domain" "$inbound_uuid" "$panel_domain"; then
    return 1
  fi
}

# Включение модуля: all-in-one.sh

# ===================================================================================
#                              УСТАНОВКА ПАНЕЛИ REMNAWAVE
# ===================================================================================

install_panel_all_in_one() {
    clear_screen

    remove_previous_installation

    # Установка общих зависимостей
    install_dependencies

    # Создаем базовую директорию для всего проекта
    mkdir -p $REMNAWAVE_DIR/{panel,caddy}

    # Переходим в директорию панели
    cd $REMNAWAVE_DIR/panel

    # Генерация JWT секретов с помощью openssl
    JWT_AUTH_SECRET=$(openssl rand -hex 32 | tr -d '\n')
    JWT_API_TOKENS_SECRET=$(openssl rand -hex 32 | tr -d '\n')

    # Генерация безопасных учетных данных
    DB_USER="remnawave_$(openssl rand -hex 4 | tr -d '\n')"
    DB_PASSWORD=$(generate_secure_password 16)
    DB_NAME="remnawave_db"
    METRICS_PASS=$(generate_secure_password 16)

    curl -s -o .env https://raw.githubusercontent.com/remnawave/backend/refs/heads/dev/.env.sample

    # Спрашиваем, нужна ли интеграция с Telegram
    if prompt_yes_no "Хотите включить интеграцию с Telegram?"; then
        IS_TELEGRAM_ENV_VALUE="true"
        # Если интеграция с Telegram включена, запрашиваем параметры
        TELEGRAM_BOT_TOKEN=$(prompt_input "Введите токен вашего Telegram бота: " "$ORANGE")
        TELEGRAM_ADMIN_ID=$(prompt_input "Введите ID администратора Telegram: " "$ORANGE")
        NODES_NOTIFY_CHAT_ID=$(prompt_input "Введите ID чата для уведомлений: " "$ORANGE")
    else
        # Если интеграция с Telegram не включена, устанавливаем параметры в "change-me"
        IS_TELEGRAM_ENV_VALUE="false"
        show_warning "Пропуск интеграции с Telegram."
        TELEGRAM_BOT_TOKEN="change-me"
        TELEGRAM_ADMIN_ID="change-me"
        NODES_NOTIFY_CHAT_ID="change-me"
    fi

    # Запрашиваем основной домен для панели с валидацией
    SCRIPT_PANEL_DOMAIN=$(prompt_domain "Введите основной домен для вашей панели, подписок и selfsteal (например, panel.example.com)")
    check_domain_points_to_server "$SCRIPT_PANEL_DOMAIN"
    domain_check_result=$?
    if [ $domain_check_result -eq 2 ]; then
        # Пользователь решил прервать установку
        return 1
    fi
    SCRIPT_SUB_DOMAIN="$SCRIPT_PANEL_DOMAIN"
    # Запрос порта Selfsteal с валидацией и дефолтным значением 9443
    SELF_STEAL_PORT=$(read_port "Введите порт для Caddy - не должен быть 443, (можно оставить по умолчанию)" "9443")
    echo ""
    # Запрос порта API ноды с валидацией и дефолтным значением 2222
    NODE_PORT=$(read_port "Введите порт API ноды (можно оставить по умолчанию)" "2222")
    echo ""

    SUPERADMIN_USERNAME=$(generate_readable_login)
    SUPERADMIN_PASSWORD=$(generate_secure_password 25)

    update_file ".env" \
        "JWT_AUTH_SECRET" "$JWT_AUTH_SECRET" \
        "JWT_API_TOKENS_SECRET" "$JWT_API_TOKENS_SECRET" \
        "IS_TELEGRAM_ENABLED" "$IS_TELEGRAM_ENV_VALUE" \
        "TELEGRAM_BOT_TOKEN" "$TELEGRAM_BOT_TOKEN" \
        "TELEGRAM_ADMIN_ID" "$TELEGRAM_ADMIN_ID" \
        "NODES_NOTIFY_CHAT_ID" "$NODES_NOTIFY_CHAT_ID" \
        "SUB_PUBLIC_DOMAIN" "$SCRIPT_PANEL_DOMAIN/sub" \
        "DATABASE_URL" "postgresql://$DB_USER:$DB_PASSWORD@remnawave-db:5432/$DB_NAME" \
        "POSTGRES_USER" "$DB_USER" \
        "POSTGRES_PASSWORD" "$DB_PASSWORD" \
        "POSTGRES_DB" "$DB_NAME" \
        "METRICS_PASS" "$METRICS_PASS"

    # Генерация секретного ключа для защиты панели управления
    PANEL_SECRET_KEY=$(openssl rand -hex 16)

    # Создаем docker-compose.yml для панели
    curl -s -o docker-compose.yml https://raw.githubusercontent.com/remnawave/backend/refs/heads/main/docker-compose-prod.yml

    # Меняем образ на dev
    # sed -i "s|image: remnawave/backend:latest|image: remnawave/backend:dev|" docker-compose.yml

    # Создаем Makefile
    create_makefile "$REMNAWAVE_DIR/panel"

    # ===================================================================================
    # Установка Caddy для панели и подписок
    # ===================================================================================

    setup_caddy_all_in_one "$PANEL_SECRET_KEY" "$SCRIPT_PANEL_DOMAIN" "$SELF_STEAL_PORT"

    # Запуск всех контейнеров
    show_info "Запуск контейнеров..." "$BOLD_GREEN"

    # Запуск панели RemnaWave
    start_container "$REMNAWAVE_DIR/panel" "remnawave/backend" "Remnawave"

    # Запуск Caddy
    start_container "$REMNAWAVE_DIR/caddy" "caddy-remnawave" "Caddy"

    wait_for_panel "127.0.0.1:3000"

    REG_TOKEN=$(register_user "127.0.0.1:3000" "$SCRIPT_PANEL_DOMAIN" "$SUPERADMIN_USERNAME" "$SUPERADMIN_PASSWORD")

    if [ -n "$REG_TOKEN" ]; then
        vless_configuration_all_in_one "127.0.0.1:3000" "$SCRIPT_PANEL_DOMAIN" "$REG_TOKEN" "$SELF_STEAL_PORT" "$NODE_PORT"
    else
        show_error "Не удалось зарегистрировать пользователя."
        exit 1
    fi

    setup_node_all_in_one "$SCRIPT_PANEL_DOMAIN" "$SELF_STEAL_PORT" "127.0.0.1:3000" "$REG_TOKEN" "$NODE_PORT"
    # Запуск ноды
    start_container "$LOCAL_REMNANODE_DIR" "remnawave/node" "Remnawave Node"

    # Проверяем, запущена ли нода
    NODE_STATUS=$(docker compose ps --services --filter "status=running" | grep -q "node" && echo "running" || echo "stopped")

    if [ "$NODE_STATUS" = "running" ]; then
        echo -e "${BOLD_GREEN}✓ Нода Remnawave успешно установлена и запущена!${NC}"
        echo ""
    fi

    show_info "Первичный перезапуск панели"
    # Перезапуск панели
    restart_panel "true"

    wait_for_panel "127.0.0.1:3000"

    # Сохранение учетных данных в файл
    CREDENTIALS_FILE="$REMNAWAVE_DIR/panel/credentials.txt"
    echo "PANEL DOMAIN: $SCRIPT_PANEL_DOMAIN" >>"$CREDENTIALS_FILE"
    echo "PANEL URL: https://$SCRIPT_PANEL_DOMAIN?caddy=$PANEL_SECRET_KEY" >>"$CREDENTIALS_FILE"
    echo "" >>"$CREDENTIALS_FILE"
    echo "SUPERADMIN USERNAME: $SUPERADMIN_USERNAME" >>"$CREDENTIALS_FILE"
    echo "SUPERADMIN PASSWORD: $SUPERADMIN_PASSWORD" >>"$CREDENTIALS_FILE"
    echo "" >>"$CREDENTIALS_FILE"
    echo "SECRET KEY: $PANEL_SECRET_KEY" >>"$CREDENTIALS_FILE"

    # Установка безопасных прав на файл с учетными данными
    chmod 600 "$CREDENTIALS_FILE"

    display_panel_installation_complete_message
}


# Проверка на root права
if [ "$(id -u)" -ne 0 ]; then
    echo "Ошибка: Этот скрипт должен быть запущен от имени root (sudo)"
    exit 1
fi

clear



# ===================================================================================
#                              ГЛАВНОЕ МЕНЮ
# ===================================================================================

main() {

    while true; do
    draw_info_box "Панель Remnawave" "Автоматическая установка by uphantom"

        echo -e "${BOLD_BLUE_MENU}Пожалуйста, выберите компонент для установки:${NC}"
        echo
        echo -e "  ${GREEN}1. ${NC}Установка панели"
        echo -e "  ${GREEN}2. ${NC}Установка ноды"
        echo -e "  ${GREEN}3. ${NC}Упрощенная установка (панель + нода)"
        echo -e "  ${GREEN}4. ${NC}Перезапустить панель"
        echo -e "  ${GREEN}5. ${NC}Включить BBR"
        echo -e "  ${GREEN}6. ${NC}Выход"
        echo
        echo -ne "${BOLD_BLUE_MENU}Выберите опцию (1-6): ${NC}"
        read choice

        case $choice in
        1)
            install_panel
            ;;
        2)
            setup_node
            ;;
        3)
            install_panel_all_in_one
            ;;
        4)
            restart_panel
            ;;
        5)
            enable_bbr
            ;;
        6)
            echo "Готово."
            break
            ;;
        *)
            clear
            draw_info_box "Панель Remnawave" "Расширенная настройка $VERSION"
            echo -e "${BOLD_RED}Неверный выбор, пожалуйста, попробуйте снова.${NC}"
            sleep 1
            ;;
        esac
    done
}

# Запуск основной функции
main
