#!/bin/bash

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
