#!/bin/bash
set -e

[ $(id -u) -eq 0 ] || {
    echo need root
    exit 1
}

trap 'rm -f host-only.xml' INT TERM EXIT

cat >host-only.xml <<'EOF'
<network>
  <name>virhost0</name>
  <bridge name="virhost0" stp="on" delay="0" />
  <ip address="192.168.123.1" netmask="255.255.255.0">
    <dhcp>
      <range start="192.168.123.100" end="192.168.123.254" />
    </dhcp>
  </ip>
</network>
EOF

virsh net-define host-only.xml
virsh net-start virhost0
virsh net-autostart virhost0

echo allow virhost0 >> /etc/qemu/bridge.conf
