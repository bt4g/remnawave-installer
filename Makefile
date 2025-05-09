# Main variables
BUILD_DIR = dist
SRC_DIR = src
MODULES_DIR = $(SRC_DIR)/modules
SHELL = /bin/bash

# Result file name
TARGET = install_remnawave.sh

# List of all modules in the order of inclusion
MODULES = $(MODULES_DIR)/shared/common.sh \
          $(MODULES_DIR)/shared/ui.sh \
          $(MODULES_DIR)/shared/utils.sh \
          $(MODULES_DIR)/shared/security.sh \
          $(MODULES_DIR)/shared/validation.sh \
          $(MODULES_DIR)/shared/docker.sh \
          $(MODULES_DIR)/shared/api.sh \
          $(MODULES_DIR)/shared/vless.sh \
		  $(MODULES_DIR)/tools/tools.sh \
          $(MODULES_DIR)/dependencies/dependencies.sh \
          $(MODULES_DIR)/remnawave-subscription-page/remnawave-subscription-page.sh \
          $(MODULES_DIR)/caddy/caddy.sh \
          $(MODULES_DIR)/panel/vless-configuration.sh \
          $(MODULES_DIR)/panel/panel.sh \
          $(MODULES_DIR)/selfsteal/selfsteal.sh \
          $(MODULES_DIR)/node/node.sh \
          $(MODULES_DIR)/all-in-one/setup-node.sh \
          $(MODULES_DIR)/all-in-one/setup-caddy.sh \
          $(MODULES_DIR)/all-in-one/vless-configuration.sh \
		  $(MODULES_DIR)/all-in-one/setup.sh

.PHONY: all
all: clean build

# Create build directory
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# Build script
.PHONY: build
build: $(BUILD_DIR)
	@echo "Building Remnawave installer..."
	@# Remove previous build if it exists
	@rm -f $(BUILD_DIR)/$(TARGET)
	@echo '#!/bin/bash' > $(BUILD_DIR)/$(TARGET)
	@echo '' >> $(BUILD_DIR)/$(TARGET)
	@echo '# Remnawave Installer ' >> $(BUILD_DIR)/$(TARGET)
	@echo '' >> $(BUILD_DIR)/$(TARGET)
	
	@# Add module contents, removing shebang from each file
	@for module in $(MODULES); do \
		echo "# Including module: $$(basename $$module)" >> $(BUILD_DIR)/$(TARGET); \
		tail -n +2 $$module | grep -v '^[[:space:]]*#' >> $(BUILD_DIR)/$(TARGET); \
		echo '' >> $(BUILD_DIR)/$(TARGET); \
	done
	
	@# Add main.sh
	@tail -n +2 $(SRC_DIR)/main.sh | grep -v '^[[:space:]]*#' >> $(BUILD_DIR)/$(TARGET)
	
	@# Make script executable
	@chmod +x $(BUILD_DIR)/$(TARGET)
	@echo "Installer successfully built: $(BUILD_DIR)/$(TARGET)"

# Clean
.PHONY: clean
clean:
	@rm -rf $(BUILD_DIR)
	@echo "Build directory cleaned."

# Install
.PHONY: install
install: all
	@echo "Copying script to /usr/local/bin..."
	@sudo cp $(BUILD_DIR)/$(TARGET) /usr/local/bin/$(TARGET)
	@sudo chmod +x /usr/local/bin/$(TARGET)
	@echo "Installation completed. Run '$(TARGET)' to install Remnawave."

# Testing
.PHONY: test
test: all
	@echo "Checking script syntax..."
	@bash -n $(BUILD_DIR)/$(TARGET)
	@echo "Script syntax is correct."

# Debug
.PHONY: debug
debug: all
	@echo "Running in debug mode..."
	@bash -x $(BUILD_DIR)/$(TARGET)
