#!/bin/bash

GREEN='\e[0;32m'
RED='\e[0;31m'
YELLOW='\e[0;33m'
NC='\e[0m'

if [ -f .env ]; then
    POSTGRES_USER=$(grep -oP '^POSTGRES_USER=\K.*' .env)
    POSTGRES_PASSWORD=$(grep -oP '^POSTGRES_PASSWORD=\K.*' .env)
    POSTGRES_DB=$(grep -oP '^POSTGRES_DB=\K.*' .env)
else
    echo -e "${RED}Файл .env не найден. Попробуем стандартные реквизиты доступа к базе${NC}"
    echo -e "${RED}Если вы их меняли, то запустите скрипт из директории Remnawave${NC}"
    POSTGRES_USER="postgres"
    POSTGRES_PASSWORD="postgres"
    POSTGRES_DB="postgres"
fi

CONTAINER_NAME="remnawave-db"
TABLE_NAME="admin"

if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo -e "${RED}Контейнер $CONTAINER_NAME не запущен!${NC}"
    exit 1
fi

echo -e "${YELLOW}Вы собираетесь удалить запись суперадмина из таблицы $TABLE_NAME${NC}"
read -p "Продолжить? (y/yes): " CONFIRM

if [[ "${CONFIRM,,}" != "y" && "${CONFIRM,,}" != "yes" ]]; then
    echo -e "${YELLOW}Операция отменена${NC}"
    exit 0
fi

SQL_QUERY="DELETE FROM $TABLE_NAME WHERE ctid IN (SELECT ctid FROM $TABLE_NAME LIMIT 1);"

echo "Удаление суперадмина из таблицы $TABLE_NAME..."
RESULT=$(docker exec $CONTAINER_NAME psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$SQL_QUERY")

if [[ $? -eq 0 ]]; then
    if [[ $RESULT == *"DELETE 0"* ]]; then
        echo -e "${YELLOW}Записи суперадмина не найдены в таблице $TABLE_NAME${NC}"
    else
        echo -e "${GREEN}Запись успешно удалена${NC}"
    fi
else
    echo -e "${RED}Ошибка при удалении записи${NC}"
    exit 1
fi
