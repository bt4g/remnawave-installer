#!/bin/bash

# ===================================================================================
#                              ENGLISH TRANSLATIONS
# ===================================================================================

# Note: TRANSLATIONS array is already declared in i18n.sh

# Error messages
TRANSLATIONS_EN[error_root_required]="Error: This script must be run as root (sudo)"
TRANSLATIONS_EN[error_invalid_choice]="Invalid choice, please try again."
TRANSLATIONS_EN[error_empty_response]="Error: Empty response from server when creating user."
TRANSLATIONS_EN[error_failed_create_user]="Error: Failed to create user. HTTP status:"
TRANSLATIONS_EN[error_passwords_no_match]="Passwords do not match. Please try again."
TRANSLATIONS_EN[error_enter_yn]="Please enter 'y' or 'n'."
TRANSLATIONS_EN[error_enter_number_between]="Please enter a number between"

# Main menu
TRANSLATIONS_EN[main_menu_title]="Remnawave Panel Installer by uphantom v"
TRANSLATIONS_EN[main_menu_script_branch]="Script branch:"
TRANSLATIONS_EN[main_menu_panel_branch]="Panel branch:"
TRANSLATIONS_EN[main_menu_install_components]="Install Panel/Node"
TRANSLATIONS_EN[main_menu_update_components]="Update Panel/Node"
TRANSLATIONS_EN[main_menu_restart_panel]="Restart panel"
TRANSLATIONS_EN[main_menu_remove_panel]="Remove panel"
TRANSLATIONS_EN[main_menu_rescue_cli]="Remnawave Rescue CLI [Reset admin]"
TRANSLATIONS_EN[main_menu_show_credentials]="Show panel access credentials"
TRANSLATIONS_EN[main_menu_warp_integration]="Add WARP integration"
TRANSLATIONS_EN[main_menu_exit]="Exit"
TRANSLATIONS_EN[main_menu_select_option]="Select option:"

# Installation menu
TRANSLATIONS_EN[install_menu_title]="Install Panel/Node"
TRANSLATIONS_EN[install_menu_panel_only]="Panel Only:"
TRANSLATIONS_EN[install_menu_panel_full_security]="Panel with FULL Caddy security (recommended)"
TRANSLATIONS_EN[install_menu_panel_simple_security]="Panel with SIMPLE cookie security"
TRANSLATIONS_EN[install_menu_node_only]="Node Only:"
TRANSLATIONS_EN[install_menu_node_separate]="Node only (for separate server)"
TRANSLATIONS_EN[install_menu_all_in_one]="All-in-One:"
TRANSLATIONS_EN[install_menu_panel_node_full]="Panel + Node with FULL Caddy security"
TRANSLATIONS_EN[install_menu_panel_node_simple]="Panel + Node with SIMPLE cookie security"
TRANSLATIONS_EN[install_menu_back]="Back to main menu"

# Update menu
TRANSLATIONS_EN[update_menu_title]="Update Panel/Node"
TRANSLATIONS_EN[update_menu_panel_only]="Panel Only:"
TRANSLATIONS_EN[update_menu_panel_update]="Update Panel"
TRANSLATIONS_EN[update_menu_node_only]="Node Only:"
TRANSLATIONS_EN[update_menu_node_separate]="Update Node (separate server)"
TRANSLATIONS_EN[update_menu_back]="Back to main menu"

# Common prompts
TRANSLATIONS_EN[prompt_yes_no_suffix]=" (y/n): "
TRANSLATIONS_EN[prompt_yes_no_default_suffix]=" (y/n) ["
TRANSLATIONS_EN[prompt_enter_to_continue]="Press Enter to continue..."
TRANSLATIONS_EN[prompt_enter_to_return]="Press Enter to return to menu..."

# Success/Info messages
TRANSLATIONS_EN[success_bbr_enabled]="BBR successfully enabled"
TRANSLATIONS_EN[success_bbr_disabled]="BBR disabled, active cubic + fq_codel"
TRANSLATIONS_EN[success_credentials_saved]="Credentials saved in file:"
TRANSLATIONS_EN[success_installation_complete]="Installation complete. Press Enter to continue..."

# Warning messages
TRANSLATIONS_EN[warning_skipping_telegram]="Skipping Telegram integration."
TRANSLATIONS_EN[warning_bbr_not_configured]="BBR was not configured in /etc/sysctl.conf"
TRANSLATIONS_EN[warning_enter_different_domain]="Please enter a different domain for"

# Info messages
TRANSLATIONS_EN[info_removing_bbr_config]="Removing BBR configuration from /etc/sysctl.conf…"
TRANSLATIONS_EN[info_installation_directory]="Installation directory:"

# BBR related
TRANSLATIONS_EN[bbr_enable]="Enable BBR"
TRANSLATIONS_EN[bbr_disable]="Disable BBR"

# Telegram configuration
TRANSLATIONS_EN[telegram_enable_notifications]="Do you want to enable Telegram notifications?"
TRANSLATIONS_EN[telegram_bot_token]="Enter your Telegram bot token: "
TRANSLATIONS_EN[telegram_enable_user_notifications]="Do you want to enable notifications about user events? (if disabled, only node event notifications will be sent)"
TRANSLATIONS_EN[telegram_users_chat_id]="Enter the chat ID for user event notifications: "
TRANSLATIONS_EN[telegram_nodes_chat_id]="Enter the chat ID for node event notifications: "
TRANSLATIONS_EN[telegram_use_topics]="Do you want to use Telegram topics?"
TRANSLATIONS_EN[telegram_users_thread_id]="Enter the thread ID for user events: "
TRANSLATIONS_EN[telegram_nodes_thread_id]="Enter the thread ID for node events: "

# Domain configuration
TRANSLATIONS_EN[domain_panel_prompt]="Enter Panel domain (will be used on panel server), e.g. panel.example.com"
TRANSLATIONS_EN[domain_subscription_prompt]="Enter Subscription domain (will be used on panel server), e.g. sub.example.com"
TRANSLATIONS_EN[domain_selfsteal_prompt]="Enter Selfsteal domain (will be used on node server), e.g. domain.example.com"

# Authentication
TRANSLATIONS_EN[auth_admin_username]="Enter admin username: "
TRANSLATIONS_EN[auth_admin_password]="Enter admin password: "
TRANSLATIONS_EN[auth_admin_email]="Enter the admin email for Caddy Auth"
TRANSLATIONS_EN[auth_confirm_password]="Please confirm your password"

# Panel authentication
TRANSLATIONS_EN[panel_invalid_auth_type]="Invalid authentication type"
TRANSLATIONS_EN[panel_auth_type_options]="Valid options: 'cookie' or 'full'"

# Results display
TRANSLATIONS_EN[results_secure_login_link]="Secure login link (with secret key):"
TRANSLATIONS_EN[results_user_subscription_url]="User subscription URL:"
TRANSLATIONS_EN[results_admin_login]="Admin login:"
TRANSLATIONS_EN[results_admin_password]="Admin password:"
TRANSLATIONS_EN[results_caddy_auth_login]="Caddy auth login:"
TRANSLATIONS_EN[results_caddy_auth_password]="Caddy auth password:"
TRANSLATIONS_EN[results_remnawave_admin_login]="Remnawave admin login:"
TRANSLATIONS_EN[results_remnawave_admin_password]="Remnawave admin password:"
TRANSLATIONS_EN[results_auth_portal_page]="Auth Portal page:"

# QR Code
TRANSLATIONS_EN[qr_subscription_url]="Subscription URL QR Code"

# Password validation
TRANSLATIONS_EN[password_min_length]="Password must contain at least"
TRANSLATIONS_EN[password_min_length_suffix]="characters."
TRANSLATIONS_EN[password_need_digit]="Password must contain at least one digit."
TRANSLATIONS_EN[password_need_lowercase]="Password must contain at least one lowercase letter."
TRANSLATIONS_EN[password_need_uppercase]="Password must contain at least one uppercase letter."
TRANSLATIONS_EN[password_try_again]="Please try again."

# Ports and network
TRANSLATIONS_EN[port_panel_prompt]="Enter Panel port (default: 443): "
TRANSLATIONS_EN[port_node_prompt]="Enter Node port (default: 2222): "
TRANSLATIONS_EN[port_caddy_local_prompt]="Enter Caddy local port (default: 9443): "

# Installation process
TRANSLATIONS_EN[installation_preparing]="Preparing installation..."
TRANSLATIONS_EN[installation_starting_services]="Starting services..."
TRANSLATIONS_EN[installation_configuring]="Configuring..."

# Credentials
TRANSLATIONS_EN[credentials_found]="Panel access credentials found:"
TRANSLATIONS_EN[credentials_not_found]="Credentials file not found!"
TRANSLATIONS_EN[credentials_file_location]="The credentials file does not exist at:"
TRANSLATIONS_EN[credentials_reasons]="This usually means:"
TRANSLATIONS_EN[credentials_reason_not_installed]="Panel is not installed yet"
TRANSLATIONS_EN[credentials_reason_incomplete]="Installation was not completed successfully"
TRANSLATIONS_EN[credentials_reason_deleted]="Credentials file was manually deleted"
TRANSLATIONS_EN[credentials_try_install]="Try installing the panel first using option 1 from the main menu."

# CLI
TRANSLATIONS_EN[cli_container_not_running]="Remnawave container is not running!"
TRANSLATIONS_EN[cli_ensure_panel_running]="Please make sure the panel is installed and running."
TRANSLATIONS_EN[cli_session_completed]="CLI session completed successfully"
TRANSLATIONS_EN[cli_session_failed]="CLI session failed or was interrupted"

# Removal
TRANSLATIONS_EN[removal_installation_detected]="RemnaWave installation detected."
TRANSLATIONS_EN[removal_confirm_delete]="Are you sure you want to completely DELETE Remnawave? IT WILL REMOVE ALL DATA!!! Continue?"
TRANSLATIONS_EN[removal_previous_detected]="Previous RemnaWave installation detected."
TRANSLATIONS_EN[removal_confirm_continue]="To continue, you need to DELETE previous Remnawave installation. IT WILL REMOVE ALL DATA!!! Continue?"
TRANSLATIONS_EN[removal_complete_success]="Remnawave has been completely removed from your system. Press any key to continue..."
TRANSLATIONS_EN[removal_previous_success]="Previous installation removed."
TRANSLATIONS_EN[removal_no_installation]="No Remnawave installation detected on this system."

# Restart
TRANSLATIONS_EN[restart_panel_dir_not_found]="Error: panel directory not found at /opt/remnawave!"
TRANSLATIONS_EN[restart_install_panel_first]="Please install Remnawave panel first."
TRANSLATIONS_EN[restart_compose_not_found]="Error: docker-compose.yml not found in panel directory!"
TRANSLATIONS_EN[restart_installation_corrupted]="Panel installation may be corrupted or incomplete."
TRANSLATIONS_EN[restart_starting_panel]="Starting main panel..."
TRANSLATIONS_EN[restart_starting_subscription]="Starting subscription page..."
TRANSLATIONS_EN[restart_success]="Panel restarted successfully"

# Update
TRANSLATIONS_EN[update_panel_dir_not_found]="Error: panel directory not found at /opt/remnawave!"
TRANSLATIONS_EN[update_node_dir_not_found]="Error: node directory not found at /opt/remnanode!"
TRANSLATIONS_EN[update_install_first]="Please install components first."
TRANSLATIONS_EN[update_compose_not_found]="Error: docker-compose.yml not found!"
TRANSLATIONS_EN[update_installation_corrupted]="Installation may be corrupted or incomplete."
TRANSLATIONS_EN[update_warning_title]="⚠️  IMPORTANT: Before updating"
TRANSLATIONS_EN[update_warning_backup]="• Make sure you have backups of your data"
TRANSLATIONS_EN[update_warning_changelog]="• Read the changelog before updating:"
TRANSLATIONS_EN[update_warning_panel_releases]="  Panel: https://github.com/remnawave/panel/releases/"
TRANSLATIONS_EN[update_warning_node_releases]="  Node: https://hub.remna.st/changelog"
TRANSLATIONS_EN[update_warning_downtime]="• Update process will cause temporary service downtime"
TRANSLATIONS_EN[update_warning_confirm]="Do you want to continue with the update?"
TRANSLATIONS_EN[update_checking_images]="Checking for image updates..."
TRANSLATIONS_EN[update_pulling_images]="Pulling latest images..."
TRANSLATIONS_EN[update_no_updates_available]="No updates available - all images are already up to date"
TRANSLATIONS_EN[update_images_updated]="New images downloaded, proceeding with restart..."
TRANSLATIONS_EN[update_pull_failed]="Failed to pull images"
TRANSLATIONS_EN[update_stopping_services]="Stopping services..."
TRANSLATIONS_EN[update_starting_services]="Starting updated services..."
TRANSLATIONS_EN[update_panel_success]="Panel updated successfully"
TRANSLATIONS_EN[update_node_success]="Node updated successfully"
TRANSLATIONS_EN[update_all_success]="Panel and Node updated successfully"
TRANSLATIONS_EN[update_no_restart_needed]="No restart needed - services are already running the latest versions"
TRANSLATIONS_EN[update_cleaning_images]="Cleaning unused images..."
TRANSLATIONS_EN[update_cleanup_complete]="Cleanup completed"
TRANSLATIONS_EN[update_cancelled]="Update cancelled by user"

# Services
TRANSLATIONS_EN[services_starting_containers]="Starting containers..."
TRANSLATIONS_EN[services_installation_stopped]="Installation stopped"

# System
TRANSLATIONS_EN[system_distro_not_supported]="Distribution"
TRANSLATIONS_EN[system_dependencies_success]="All dependencies installed and configured."
TRANSLATIONS_EN[system_created_directory]="Created directory:"
TRANSLATIONS_EN[system_installation_cancelled]="Installation cancelled. Returning to main menu."

# Common prompts
TRANSLATIONS_EN[prompt_press_any_key]="Press any key to continue..."

# Spinner messages
TRANSLATIONS_EN[spinner_generating_keys]="Generating x25519 keys..."
TRANSLATIONS_EN[spinner_updating_xray]="Updating Xray configuration..."
TRANSLATIONS_EN[spinner_registering_user]="Registering user"
TRANSLATIONS_EN[spinner_getting_public_key]="Getting public key..."
TRANSLATIONS_EN[spinner_creating_node]="Creating node..."
TRANSLATIONS_EN[spinner_getting_inbounds]="Getting list of inbounds..."
TRANSLATIONS_EN[spinner_creating_host]="Creating host for"
TRANSLATIONS_EN[spinner_cleaning_services]="Cleaning up"
TRANSLATIONS_EN[spinner_force_removing]="Force removing container"
TRANSLATIONS_EN[spinner_removing_directory]="Removing directory"
TRANSLATIONS_EN[spinner_stopping_subscription]="Stopping remnawave-subscription-page container"
TRANSLATIONS_EN[spinner_restarting_panel]="Restarting panel..."
TRANSLATIONS_EN[spinner_launching]="Launching"
TRANSLATIONS_EN[spinner_updating_apt_cache]="Updating APT cache"
TRANSLATIONS_EN[spinner_installing_packages]="Installing packages:"
TRANSLATIONS_EN[spinner_starting_docker]="Starting Docker daemon"
TRANSLATIONS_EN[spinner_docker_already_running]="Docker daemon already running"
TRANSLATIONS_EN[spinner_adding_user_to_group]="Adding user to group"
TRANSLATIONS_EN[spinner_firewall_already_set]="Firewall already set"
TRANSLATIONS_EN[spinner_configuring_firewall]="Configuring firewall"
TRANSLATIONS_EN[spinner_auto_updates_already_set]="Auto-updates already set"
TRANSLATIONS_EN[spinner_setting_auto_updates]="Setting auto-updates"
TRANSLATIONS_EN[spinner_downloading_static_files]="Downloading static files for the selfsteal site..."

# Config
TRANSLATIONS_EN[config_invalid_arguments]="Error: invalid number of arguments. Should be even number of keys and values."
TRANSLATIONS_EN[config_domain_already_used]="Domain"
TRANSLATIONS_EN[config_domains_must_be_unique]="Each domain must be unique: panel domain, subscription domain, and selfsteal domain must all be different."
TRANSLATIONS_EN[config_caddy_port_available]="Required Caddy port 9443 is available"
TRANSLATIONS_EN[config_caddy_port_in_use]="Required Caddy port 9443 is already in use!"
TRANSLATIONS_EN[config_node_port_available]="Required Node API port 2222 is available"
TRANSLATIONS_EN[config_node_port_in_use]="Required Node API port 2222 is already in use!"
TRANSLATIONS_EN[config_separate_installation_port_required]="For separate panel and node installation, port"
TRANSLATIONS_EN[config_free_port_and_retry]="Please free up port"
TRANSLATIONS_EN[config_installation_cannot_continue]="Installation cannot continue with occupied port"

# Misc
TRANSLATIONS_EN[misc_qr_generation_failed]="QR code generation failed"

# Network
TRANSLATIONS_EN[network_error_port_number]="Error: Port must be a number."
TRANSLATIONS_EN[network_error_port_range]="Error: Port must be between 1 and 65535."
TRANSLATIONS_EN[network_invalid_email]="Invalid email format."
TRANSLATIONS_EN[network_proceed_with_value]="Proceed with this value? Current value:"
TRANSLATIONS_EN[network_using_default_port]="Using default port:"
TRANSLATIONS_EN[network_port_in_use]="port is already in use. Finding available port..."
TRANSLATIONS_EN[network_using_port]="Using port:"
TRANSLATIONS_EN[network_failed_find_port]="Failed to find an available port for"
TRANSLATIONS_EN[network_invalid_domain]="Invalid domain format. Please try again."
TRANSLATIONS_EN[network_failed_determine_ip]="Failed to determine domain or server IP address."
TRANSLATIONS_EN[network_make_sure_domain]="Make sure that the domain"
TRANSLATIONS_EN[network_points_to_server]="is properly configured and points to the server"
TRANSLATIONS_EN[network_continue_despite_ip]="Continue with this domain despite being unable to verify its IP address?"
TRANSLATIONS_EN[network_domain_points_cloudflare]="Domain"
TRANSLATIONS_EN[network_points_cloudflare_ip]="points to Cloudflare IP"
TRANSLATIONS_EN[network_disable_cloudflare]="Disable Cloudflare proxying - selfsteal domain proxying is not allowed."
TRANSLATIONS_EN[network_continue_despite_cloudflare]="Continue with this domain despite Cloudflare proxy configuration issue?"
TRANSLATIONS_EN[network_domain_points_server]="Domain"
TRANSLATIONS_EN[network_points_this_server]="points to this server IP"
TRANSLATIONS_EN[network_separate_installation_note]="For separate installation, selfsteal domain should point to the node server, not the panel server."
TRANSLATIONS_EN[network_continue_despite_current_server]="Continue with this domain despite it pointing to the current server?"
TRANSLATIONS_EN[network_domain_points_different]="Domain"
TRANSLATIONS_EN[network_points_different_ip]="points to IP address"
TRANSLATIONS_EN[network_differs_from_server]="which differs from the server IP"
TRANSLATIONS_EN[network_continue_despite_mismatch]="Continue with this domain despite the IP address mismatch?"

# API
TRANSLATIONS_EN[api_empty_server_response]="Empty server response"
TRANSLATIONS_EN[api_registration_failed]="Registration failed: unknown error"
TRANSLATIONS_EN[api_failed_get_public_key]="Error: Failed to get public key."
TRANSLATIONS_EN[api_failed_extract_public_key]="Error: Failed to extract public key from response."
TRANSLATIONS_EN[api_empty_response_creating_node]="Error: Empty response from server when creating node."
TRANSLATIONS_EN[api_failed_create_node]="Error: Failed to create node, response:"
TRANSLATIONS_EN[api_empty_response_getting_inbounds]="Error: Empty response from server when getting inbounds."
TRANSLATIONS_EN[api_failed_extract_uuid]="Error: Failed to extract UUID from response."
TRANSLATIONS_EN[api_empty_response_creating_host]="Error: Empty response from server when creating host."
TRANSLATIONS_EN[api_failed_create_host]="Error: Failed to create host."
TRANSLATIONS_EN[api_empty_response_creating_user]="Error: Empty response from server when creating user."
TRANSLATIONS_EN[api_failed_create_user_status]="Error: Failed to create user. HTTP status:"
TRANSLATIONS_EN[api_failed_create_user_format]="Error: Failed to create user, invalid response format:"
TRANSLATIONS_EN[api_failed_register_user]="Failed to register user."
TRANSLATIONS_EN[api_request_body_was]="Request body was:"
TRANSLATIONS_EN[api_response]="Response:"

# Validation
TRANSLATIONS_EN[validation_value_min]="Value must be at least"
TRANSLATIONS_EN[validation_value_max]="Value must be at most"
TRANSLATIONS_EN[validation_enter_numeric]="Please enter a valid numeric value."
TRANSLATIONS_EN[validation_input_empty]="Input cannot be empty. Please enter a valid domain or IP address."
TRANSLATIONS_EN[validation_invalid_ip]="Invalid IP address format. IP must be in format X.X.X.X, where X is a number from 0 to 255."
TRANSLATIONS_EN[validation_invalid_domain]="Invalid domain name format. Domain must contain at least one dot and not start/end with dot or dash."
TRANSLATIONS_EN[validation_use_only_letters]="Use only letters, digits, dots, and dashes."
TRANSLATIONS_EN[validation_invalid_domain_ip]="Invalid domain or IP address format."
TRANSLATIONS_EN[validation_domain_format]="Domain must contain at least one dot and not start/end with dot or dash."
TRANSLATIONS_EN[validation_ip_format]="IP address must be in format X.X.X.X, where X is a number from 0 to 255."
TRANSLATIONS_EN[validation_max_attempts_default]="Maximum number of attempts exceeded. Using default value:"
TRANSLATIONS_EN[validation_max_attempts_no_input]="Maximum number of attempts exceeded. No valid input provided."
TRANSLATIONS_EN[validation_cannot_continue]="Installation cannot continue without a valid domain or IP address."

# VLESS
TRANSLATIONS_EN[vless_failed_generate_keys]="Error: Failed to generate keys."
TRANSLATIONS_EN[vless_empty_response_xray]="Error: Empty response from server when updating Xray config."
TRANSLATIONS_EN[vless_failed_update_xray]="Error: Failed to update Xray configuration."

# Node
TRANSLATIONS_EN[node_port_9443_in_use]="Required Caddy port 9443 is already in use!"
TRANSLATIONS_EN[node_separate_port_9443]="For separate node installation, port 9443 must be available."
TRANSLATIONS_EN[node_free_port_9443]="Please free up port 9443 and try again."
TRANSLATIONS_EN[node_cannot_continue_9443]="Installation cannot continue with occupied port 9443"
TRANSLATIONS_EN[node_port_2222_in_use]="Required Node API port 2222 is already in use!"
TRANSLATIONS_EN[node_separate_port_2222]="For separate node installation, port 2222 must be available."
TRANSLATIONS_EN[node_free_port_2222]="Please free up port 2222 and try again."
TRANSLATIONS_EN[node_cannot_continue_2222]="Installation cannot continue with occupied port 2222"
TRANSLATIONS_EN[node_enter_ssl_cert]="Enter the server certificate in format SSL_CERT=\"...\" (paste the content and press Enter twice):"
TRANSLATIONS_EN[node_ssl_cert_valid]="✓ SSL certificate format is valid"
TRANSLATIONS_EN[node_ssl_cert_invalid]="✗ Invalid SSL certificate format. Please try again."
TRANSLATIONS_EN[node_ssl_cert_expected]="Expected format: SSL_CERT=\"...eyJub2RlQ2VydFBldW0iOiAi...\""
TRANSLATIONS_EN[node_port_info]="• Node port:"
TRANSLATIONS_EN[node_directory_info]="• Node directory:"

# Container
TRANSLATIONS_EN[container_error_provide_args]="Error: provide directory and display name"
TRANSLATIONS_EN[container_error_directory_not_found]="Error: directory \"%s\" not found"
TRANSLATIONS_EN[container_error_compose_not_found]="Error: docker-compose.yml not found in \"%s\""
TRANSLATIONS_EN[container_error_docker_not_installed]="Error: Docker is not installed or not in PATH"
TRANSLATIONS_EN[container_error_docker_not_running]="Error: Docker daemon is not running"
TRANSLATIONS_EN[container_rate_limit_error]="✖ Docker Hub rate limit while pulling images for \"%s\"."
TRANSLATIONS_EN[container_rate_limit_cause]="Cause: pull rate limit exceeded."
TRANSLATIONS_EN[container_rate_limit_solutions]="Possible solutions:"
TRANSLATIONS_EN[container_rate_limit_wait]="1. Wait ~6 h and retry"
TRANSLATIONS_EN[container_rate_limit_login]="2. docker login"
TRANSLATIONS_EN[container_rate_limit_vpn]="3. Use VPN / other IP"
TRANSLATIONS_EN[container_rate_limit_mirror]="4. Set up a mirror"
TRANSLATIONS_EN[container_success_up]="✔ \"%s\" is up (services: %s)."
TRANSLATIONS_EN[container_failed_start]="✖ \"%s\" failed to start entirely."
TRANSLATIONS_EN[container_compose_output]="→ docker compose output:"
TRANSLATIONS_EN[container_problematic_services]="→ Problematic services status:"

# General
TRANSLATIONS_EN[exiting]="Exiting."
TRANSLATIONS_EN[creating_user]="Creating user:"
TRANSLATIONS_EN[please_wait]="Please wait..."
TRANSLATIONS_EN[operation_completed]="Operation completed."

# Node setup
TRANSLATIONS_EN[node_enter_selfsteal_domain]="Enter Selfsteal domain, e.g. domain.example.com"
TRANSLATIONS_EN[node_enter_panel_ip]="Enter the IP address of the panel server (for configuring firewall)"
TRANSLATIONS_EN[node_allow_connections]="Allow connections from panel server to node port 2222..."
TRANSLATIONS_EN[node_enter_ssl_cert_prompt]="Enter the server certificate in format SSL_CERT=\"...\" (paste the content and press Enter twice):"
TRANSLATIONS_EN[node_press_enter_return]="Press Enter to return to the main menu..."

# VLESS configuration
TRANSLATIONS_EN[vless_enter_node_host]="Enter the IP address or domain of the node server (if different from Selfsteal domain)"
TRANSLATIONS_EN[vless_public_key_required]="Public key (required for node installation):"

# Container names
TRANSLATIONS_EN[container_name_remnawave_panel]="Remnawave Panel"
TRANSLATIONS_EN[container_name_subscription_page]="Subscription Page"
TRANSLATIONS_EN[container_name_remnawave_node]="Remnawave Node"

# Selfsteal
TRANSLATIONS_EN[selfsteal_installation_stopped]="Installation stopped"
TRANSLATIONS_EN[selfsteal_domain_info]="• Domain:"
TRANSLATIONS_EN[selfsteal_port_info]="• Port:"
TRANSLATIONS_EN[selfsteal_directory_info]="• Directory:"

# WARP integration
TRANSLATIONS_EN[warp_title]="WARP Integration Setup"
TRANSLATIONS_EN[warp_checking_installation]="Checking panel installation..."
TRANSLATIONS_EN[warp_panel_not_found]="Panel installation not found"
TRANSLATIONS_EN[warp_panel_not_running]="Panel is not running"
TRANSLATIONS_EN[warp_credentials_not_found]="Panel credentials not found"
TRANSLATIONS_EN[warp_terms_title]="Cloudflare WARP Terms of Service"
TRANSLATIONS_EN[warp_terms_text]="This project is in no way affiliated with Cloudflare.\nBy proceeding, you agree to Cloudflare's Terms of Service:"
TRANSLATIONS_EN[warp_terms_url]="https://www.cloudflare.com/application/terms/"
TRANSLATIONS_EN[warp_terms_confirm]="Do you agree to the terms and want to continue?"
TRANSLATIONS_EN[warp_terms_declined]="WARP integration cancelled"
TRANSLATIONS_EN[warp_downloading_wgcf]="Downloading wgcf utility..."
TRANSLATIONS_EN[warp_installing_wgcf]="Installing wgcf..."
TRANSLATIONS_EN[warp_authenticating_panel]="Authenticating with panel..."
TRANSLATIONS_EN[warp_registering_account]="Registering WARP account..."
TRANSLATIONS_EN[warp_generating_config]="Generating WireGuard configuration..."
TRANSLATIONS_EN[warp_getting_current_config]="Getting current XRAY configuration..."
TRANSLATIONS_EN[warp_updating_config]="Updating XRAY configuration with WARP..."
TRANSLATIONS_EN[warp_success]="WARP integration added successfully!"
TRANSLATIONS_EN[warp_success_details]="WARP outbound has been added to your XRAY configuration.\nThe following domains will now route through WARP:\n- Google services (Gemini)\n- OpenAI\n- Spotify\n- Canva\n- ipinfo.io \n- You can add more domains in the panel, by editing the Xray config."
TRANSLATIONS_EN[warp_failed_download]="Failed to download wgcf"
TRANSLATIONS_EN[warp_failed_install]="Failed to install wgcf"
TRANSLATIONS_EN[warp_failed_register]="Failed to register WARP account"
TRANSLATIONS_EN[warp_failed_generate]="Failed to generate WireGuard configuration"
TRANSLATIONS_EN[warp_failed_get_config]="Failed to get current XRAY configuration"
TRANSLATIONS_EN[warp_failed_update_config]="Failed to update XRAY configuration"
TRANSLATIONS_EN[warp_failed_auth]="Failed to authenticate with panel"
TRANSLATIONS_EN[warp_already_configured]="WARP is already configured in XRAY"
