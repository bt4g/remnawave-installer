# Основные переменные
BUILD_DIR = dist
SRC_DIR = src
MODULES_DIR = $(SRC_DIR)/modules
SHELL = /bin/bash

# Имя результирующего файла
TARGET = install_remnawave.sh

# Список всех модулей в порядке включения
MODULES = $(MODULES_DIR)/shared/common.sh \
          $(MODULES_DIR)/shared/ui.sh \
					$(MODULES_DIR)/tools/tools.sh \
          $(MODULES_DIR)/dependencies/dependencies.sh \
          $(MODULES_DIR)/remnawave-subscription-page/remnawave-subscription-page.sh \
          $(MODULES_DIR)/caddy/caddy.sh \
          $(MODULES_DIR)/panel/vless-configuration.sh \
          $(MODULES_DIR)/panel/panel.sh \
          $(MODULES_DIR)/selfsteal/selfsteal.sh \
          $(MODULES_DIR)/node/node.sh \
          $(MODULES_DIR)/all-in-one/setup-node-all-in-one.sh \
          $(MODULES_DIR)/all-in-one/setup-caddy-all-in-one.sh \
          $(MODULES_DIR)/all-in-one/vless-configuration-all-in-one.sh \
					$(MODULES_DIR)/all-in-one/all-in-one.sh

.PHONY: all
all: clean build

# Создание директории сборки
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# Сборка скрипта
.PHONY: build
build: $(BUILD_DIR)
	@echo "Сборка установщика Remnawave..."
	@# Удаляем предыдущую сборку, если она существует
	@rm -f $(BUILD_DIR)/$(TARGET)
	@echo '#!/bin/bash' > $(BUILD_DIR)/$(TARGET)
	@echo '' >> $(BUILD_DIR)/$(TARGET)
	@echo '# Remnawave Installer ' >> $(BUILD_DIR)/$(TARGET)
	@echo '' >> $(BUILD_DIR)/$(TARGET)
	
	@# Добавляем содержимое модулей, удаляя шебанг из каждого файла
	@for module in $(MODULES); do \
		echo "# Включение модуля: $$(basename $$module)" >> $(BUILD_DIR)/$(TARGET); \
		tail -n +2 $$module | grep -v '^[[:space:]]*#' >> $(BUILD_DIR)/$(TARGET); \
		echo '' >> $(BUILD_DIR)/$(TARGET); \
	done
	
	@# Добавляем main.sh
	@tail -n +2 $(SRC_DIR)/main.sh | grep -v '^[[:space:]]*#' >> $(BUILD_DIR)/$(TARGET)
	
	@# Делаем скрипт исполняемым
	@chmod +x $(BUILD_DIR)/$(TARGET)
	@echo "Установщик успешно собран: $(BUILD_DIR)/$(TARGET)"

# Очистка
.PHONY: clean
clean:
	@rm -rf $(BUILD_DIR)
	@echo "Директория сборки очищена."

# Установка
.PHONY: install
install: all
	@echo "Копирование скрипта в /usr/local/bin..."
	@sudo cp $(BUILD_DIR)/$(TARGET) /usr/local/bin/$(TARGET)
	@sudo chmod +x /usr/local/bin/$(TARGET)
	@echo "Установка завершена. Запустите '$(TARGET)' для установки Remnawave."

# Тестирование
.PHONY: test
test: all
	@echo "Проверка синтаксиса скрипта..."
	@bash -n $(BUILD_DIR)/$(TARGET)
	@echo "Синтаксис скрипта корректен."

# Отладка
.PHONY: debug
debug: all
	@echo "Запуск в режиме отладки..."
	@bash -x $(BUILD_DIR)/$(TARGET)
