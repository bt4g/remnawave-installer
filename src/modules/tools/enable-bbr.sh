#!/bin/bash

is_bbr_enabled() {
  local cc qd
  # Check if BBR is enabled in /etc/sysctl.conf
  if grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf 2>/dev/null &&
    grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf 2>/dev/null; then
    # Really active?
    cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    qd=$(sysctl -n net.core.default_qdisc 2>/dev/null)
    [[ $cc == "bbr" && $qd == "fq" ]] && return 0
  fi
  return 1
}

get_bbr_menu_text() {
  if is_bbr_enabled; then
    echo "$(t bbr_disable)"
  else
    echo "$(t bbr_enable)"
  fi
}

apply_qdisc_now() {
  local dev
  # Check if tc command exists
  if ! command -v tc >/dev/null 2>&1; then
    return 0
  fi
  
  dev=$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')
  [[ -n $dev ]] && tc qdisc replace dev "$dev" root fq 2>/dev/null || true
}

load_bbr_module() {
  # Check if modprobe exists
  if ! command -v modprobe >/dev/null 2>&1; then
    return 0
  fi
  
  # Check if module is already loaded
  if lsmod 2>/dev/null | grep -q tcp_bbr; then
    return 0
  fi
  
  modprobe tcp_bbr 2>/dev/null || true
}

enable_bbr() {
  echo -e "\n${BOLD_GREEN}$(t bbr_enable)${NC}\n"

  load_bbr_module

  # Remove existing BBR settings
  sed -i -E \
    -e '/^\s*net\.core\.default_qdisc\s*=/d' \
    -e '/^\s*net\.ipv4\.tcp_congestion_control\s*=/d' \
    /etc/sysctl.conf 2>/dev/null || true

  # Add BBR settings
  {
    echo "net.core.default_qdisc=fq"
    echo "net.ipv4.tcp_congestion_control=bbr"
  } >>/etc/sysctl.conf

  # Apply settings
  sysctl -p >/dev/null 2>&1

  apply_qdisc_now

  show_success "$(t success_bbr_enabled)"
  echo -e "\n${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
  read -r
}

disable_bbr() {
  echo -e "\n${BOLD_GREEN}$(t bbr_disable)${NC}\n"

  if grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf 2>/dev/null ||
    grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf 2>/dev/null; then
    show_info "$(t info_removing_bbr_config)"

    sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf 2>/dev/null || true

    sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1
    sysctl -w net.core.default_qdisc=fq_codel >/dev/null 2>&1

    show_success "$(t success_bbr_disabled)"
  else
    show_warning "$(t warning_bbr_not_configured)"
  fi

  echo -e "\n${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
  read -r
}

toggle_bbr() {
  if is_bbr_enabled; then
    disable_bbr
  else
    enable_bbr
  fi
}
