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

restart_panel() {
    echo ""
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

            show_info "Останавливаем контейнеры..."

            # Останавливаем страницу подписки, если она существует
            if [ "$SUBSCRIPTION_PAGE_EXISTS" = true ]; then
                cd ~/remnawave/subscription-page && docker compose down >/dev/null 2>&1 &
                spinner $! "Останавливаем контейнер remnawave-subscription-page"
            fi

            # Останавливаем панель
            cd ~/remnawave/panel && docker compose down >/dev/null 2>&1 &
            spinner $! "Останавливаем контейнеры панели Remnawave"

            # Запускаем панель
            cd ~/remnawave/panel && docker compose up -d >/dev/null 2>&1 &
            spinner $! "Запускаем контейнеры панели Remnawave"

            # Запускаем страницу подписки, если она существует
            if [ "$SUBSCRIPTION_PAGE_EXISTS" = true ]; then
                cd ~/remnawave/subscription-page && docker compose up -d >/dev/null 2>&1 &
                spinner $! "Запускаем контейнер remnawave-subscription-page"
            fi
            show_info "Панель перезапущена"
        fi
    fi
    echo -e "${BOLD_GREEN}Нажмите Enter, чтобы продолжить...${NC}"
    read
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

# Безопасное чтение порта с валидацией
# Использование:
#   read_port "Введите порт:" "8080"
read_port() {
    local prompt="$1"
    local default_value="$2"
    local max_attempts="${3:-3}"
    local result=""
    local attempts=0

    while [ $attempts -lt $max_attempts ]; do
        # Показываем подсказку с дефолтным значением, если оно есть
        if [ -n "$default_value" ]; then
            read -p "${ORANGE}${prompt} [$default_value]:${NC}" input
        else
            read -p "${ORANGE}${prompt}:${NC}" input
        fi

        # Если ввод пустой и есть дефолтное значение, используем его
        if [ -z "$input" ] && [ -n "$default_value" ]; then
            result="$default_value"
            break
        fi

        # Валидируем ввод
        result=$(validate_port "$input" "$default_value")
        local status=$?

        if [ $status -eq 0 ]; then
            break
        else
            echo -e "${BOLD_RED}Некорректный порт. Пожалуйста, введите число от 1 до 65535.${NC}" >&2
            ((attempts++))
        fi
    done

    if [ $attempts -eq $max_attempts ]; then
        echo -e "${BOLD_RED}Превышено максимальное количество попыток. Используется значение по умолчанию: $default_value${NC}" >&2
        result="$default_value"
    fi

    echo "$result"
}
