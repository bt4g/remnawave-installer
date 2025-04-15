#!/bin/bash

# Проверка на root права
if [ "$(id -u)" -ne 0 ]; then
    echo "Ошибка: Этот скрипт должен быть запущен от имени root (sudo)"
    exit 1
fi

clear

# ===================================================================================
# Этот файл предназначен только для сборки финального скрипта.
# Для запуска используйте только собранный скрипт dist/install_remnawave.sh
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
