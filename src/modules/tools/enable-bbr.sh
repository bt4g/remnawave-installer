#!/bin/bash

is_bbr_enabled() {
  local cc qd
  # Check if BBR is enabled in /etc/sysctl.conf
  if grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf &&
    grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    # Realy active?
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
  dev=$(ip route | awk '/default/ {print $5; exit}')
  [[ -n $dev ]] && tc qdisc replace dev "$dev" root fq 2>/dev/null || true
}

load_bbr_module() {
  modprobe tcp_bbr 2>/dev/null || true
}

enable_bbr() {
  echo -e "\n${BOLD_GREEN}$(t bbr_enable)${NC}\n"

  load_bbr_module

  sed -i -E \
    -e '/^\s*net\.core\.default_qdisc\s*=/d' \
    -e '/^\s*net\.ipv4\.tcp_congestion_control\s*=/d' \
    /etc/sysctl.conf

  {
    echo "net.core.default_qdisc=fq"
    echo "net.ipv4.tcp_congestion_control=bbr"
  } >>/etc/sysctl.conf

  sysctl -p >/dev/null

  apply_qdisc_now

  show_success "$(t success_bbr_enabled)"
  echo -e "\n${BOLD_YELLOW}$(t prompt_enter_to_return)${NC}"
  read -r
}

disable_bbr() {
  echo -e "\n${BOLD_GREEN}$(t bbr_disable)${NC}\n"

  if grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf ||
    grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    show_info "$(t info_removing_bbr_config)"

    sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf

    sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null
    sysctl -w net.core.default_qdisc=fq_codel >/dev/null

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
