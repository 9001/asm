#!/bin/bash
# asm profile example @ https://github.com/9001/asm/blob/hovudstraum/p/r0cbox/sm/asm.sh
set -e

log downloading more ram
zram 256

log setting up network
printf '%s\n' "" 10.1.2.51 24 "" done n | setup-interfaces -r

log installing deps
apka -q openssh-server python3 tmux !pyc || true

log starting sshd
sed -ri 's/(Subsystem[^/]+sftp).*/\1 internal-sftp/;
    $aPermitRootLogin yes' /etc/ssh/sshd_config
printf '%s\n' k k | passwd >/dev/null
service sshd start

log starting r0c
tmux new '$AR/sm/bin/r0c.py; ash'
