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
  <ip family="ipv6" address="fd00:fda::1" prefix="96">
    <dhcp>
      <range start="fd00:fda::80" end="fd00:fda::ffff" />
    </dhcp>
  </ip>
</network>
EOF

virsh net-destroy virhost0 || true
virsh net-undefine virhost0 || true
virsh net-define host-only.xml
virsh net-start virhost0
virsh net-autostart virhost0

for f in /etc/qemu/bridge.conf /etc/qemu-kvm/bridge.conf
do echo allow virhost0 >> $f || true; done
