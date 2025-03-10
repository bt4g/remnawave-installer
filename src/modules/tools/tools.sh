#!/bin/bash

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
