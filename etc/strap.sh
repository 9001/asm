#!/bin/ash
# asm-bootstrap, ed <irc.rizon.net>, MIT-licensed, https://github.com/9001/asm

command -v bash >/dev/null || apk add -q bash 2>/dev/null >&2 || true

(cat <<'EOF'
export AR=$(dirname /media/*/the.apkovl.tar.gz)
export AP=$(df -h $AR | awk 'NR==2{sub(/.*\//,"",$1);print$1}')
export AD=$(echo $AP | awk '/p[0-9]$/{sub(/p[0-9]$/,"");print;next} {sub(/[0-9]$/,"");print}')
export HOME=/root
EOF
echo export SHELL=$(command -v bash || command -v ash)
echo export CORES=$( (cat /proc/cpuinfo;echo) | awk -F: '{gsub(/[ \t]/,"")} /^physicalid:/{p=$2;n++} /^coreid:/{i=$2;n++} /^$/&&n{t[p"."i]=1;n=0} END {n=0;for(x in t)n++;print n}')
)>/etc/profile.d/asm-paths.sh
. /etc/profile.d/asm-paths.sh
cd

# switch to shell after the first run
[ -e /dev/shm/once ] && exec $SHELL -l
touch /dev/shm/once

# load tty color scheme, announce we good
. /etc/profile.d/bifrost.sh
printf '\033[36m * %s ready\033[0m\n' "$(cat $AR/.alpine-release)"
printf '\033[s\033[H'; cat /etc/motd; printf '\033[u\033[?7h'
chvt 2; chvt 1

# switch to bash + add loggers
apk add -q util-linux bash tar 2>/dev/null >&2 &&
  sed -ri 's^/ash$^/bash^' /etc/passwd

cp -p /etc/bin/* /usr/local/bin/
export PATH="$PATH:/usr/local/bin/"

# keymap and font
yes abort | setup-keymap us us-altgr-intl 2>/dev/null >&2
stty size | awk '$1<36{exit 1}' ||
  (cd /etc/cfnt; setfont $(ls -1))

# be noisy unless muted
beeps() {
  local d=$1; shift
  [ ! -e $AR/sm/quiet ] &&
    for f in $@; do beep -f $f -l $d; done ||
    rmmod pcspkr 2>/dev/null
}
beeps 40 2000 1000

# run the payload
s=$AR/sm/asm.sh
$SHELL $s && err= || err=$?
unlog

# success? exit
[ $err ] || {
  beeps 70 523 784 1046
  exit 0
}

# error; give shell
printf "\n$s: \033[31mERROR $err\033[0m\n"
apk add -q vim tmux hexdump &
(beep -f 349 -l 200 -d 90 -r 2; rmmod pcspkr 2>/dev/null) &
exec $SHELL -l

