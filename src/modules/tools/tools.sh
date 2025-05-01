#!/bin/bash

enable_bbr() {
  # Check if BBR settings exist in sysctl.conf
  if grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf && grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo ""
    show_warning "BBR already added to /etc/sysctl.conf"
    # Check if BBR is currently active
    local current_cc=$(sysctl -n net.ipv4.tcp_congestion_control)
    local current_qdisc=$(sysctl -n net.core.default_qdisc)
    if [[ "$current_cc" == "bbr" && "$current_qdisc" == "fq" ]]; then
      show_info "BBR is active and working"
    else
      show_info "BBR is configured in configuration, but not active. Applying settings..."
      sysctl -p
    fi
    show_info "Press Enter to continue"
    read -r
  else
    # Install BBR if not found
    echo "net.core.default_qdisc=fq" >>/etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >>/etc/sysctl.conf
    # Apply changes
    sysctl -p
    show_info "BBR successfully enabled. Press Enter to continue"
    read -r
  fi
}
