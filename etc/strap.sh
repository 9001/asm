#!/bin/ash
# asm-bootstrap, ed <irc.rizon.net>, MIT-licensed, https://github.com/9001/asm

command -v bash >/dev/null || apk add -q bash 2>/dev/null >&2 || true

SEC=$(grep -qE '\bsecure\b' /proc/cmdline && echo 1 || true)
UKI=$(grep -q apkovl= /proc/cmdline && echo 1 || true)

[ -e /etc/profile.d/asm-paths.sh ] ||
(cat <<'EOF'
export AR=$(dirname /media/*/sm)
export AP=$(df -h $AR | awk 'NR==2{sub(/.*\//,"",$1);print$1}')
export AD=$(echo $AP | awk '/p[0-9]$/{sub(/p[0-9]$/,"");print;next} {sub(/[0-9]$/,"");print}')
export HOME=/root
EOF
echo export SHELL=$(command -v bash || command -v ash)
echo export CORES=$( (cat /proc/cpuinfo;echo) | awk -F: '{gsub(/[ \t]/,"")} /^physicalid:/{p=$2;n++} /^coreid:/{i=$2;n++} /^$/&&n{t[p"."i]=1;n=0} END {n=0;for(x in t)n++;print n}')
echo export SEC=$SEC
echo export UKI=$UKI
[ $UKI ] &&
  echo 'export PATH="/usr/local/bin/:$PATH"' ||
  echo 'export PATH="$AR/sm/bin:/usr/local/bin/:$PATH"'

)>/etc/profile.d/asm-paths.sh
. /etc/profile.d/asm-paths.sh
cd

# switch to shell after the first run
[ -e /dev/shm/once ] && {
  [ $SEC ] || exec $SHELL -l
  printf '\nthis console is disabled\n'
  sleep 80386
  exit 1
}
touch /dev/shm/once

# enable tty unless /proc/cmdline specifies secure
[ $SEC ] || passwd -u root 2>/dev/null

# start lo
service networking start || true

# load tty color scheme, announce we good
. /etc/profile.d/bifrost.sh
printf '\033[36m * %s ready\033[0m\n' "$(cat $AR/.alpine-release)"
printf '\033[s\033[H'; cat /etc/motd; printf '\033[u\033[?7h'
chvt 2; chvt 1

# switch to bash + add loggers
apk add -q util-linux bash tar 2>/dev/null >&2 &&
  sed -ri 's^/ash$^/bash^' /etc/passwd

cp -p /etc/bin/* /usr/local/bin/

# keymap and font
yes abort | setup-keymap us us-altgr-intl 2>/dev/null >&2
stty size | awk '$1<36{exit 1}' ||
  (cd /etc/cfnt; setfont $(ls -1))

# repos
(m=$(cat /etc/apk/arch)
  (cd $AR/apks/$m 2>/dev/null && ls -1 | grep -E 'APKINDEX.+.tar.gz') |
  while read r; do
    d=/var/ar/$r/$m
    mkdir -p $d
    find $AR/apks/$m/ | xargs -I{} ln -s {} $d/
    mv $d/$r $d/APKINDEX.tar.gz
    echo /var/ar/$r >> /etc/apk/repositories
  done
)

ebeep() {
  beeps 96 349 349 0 349 349
}

sigchk() {
  local f=$AR/sm/asm.sh
  printf ' verifying \r'
  apk add -q openssl &&
  openssl dgst -sha512 -verify /etc/asm.pub -signature $f.sig $f >/dev/null &&
  true || return 1
}

[ $UKI ] && {
  sigchk || {
    printf '\n\033[31mABORT: asm.sh does not validate against its signature, or was not signed with the expected key\n\033[0m'
    ebeep; exit 1
  }
}

# be noisy unless muted
beeps 40 2000 1000 &

# run the payload
s=$AR/sm/asm.sh
$SHELL $s && err= || err=$?
unlog

# success? exit
[ $err ] || {
  nohup beeps 70 523 784 1046 2>/dev/null &
  for a in a a a a; do sleep 0.05; [ -e nohup.out ] && break; done
  exit 0
}

# error; give shell
printf "\n$s: \033[31mERROR $err\033[0m\n"
apk add -q tmux &
(ebeep; rmmod pcspkr 2>/dev/null) &
[ $SEC ] || exec $SHELL -l

