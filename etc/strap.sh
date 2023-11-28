#!/bin/ash
# asm-bootstrap, ed <irc.rizon.net>, MIT-licensed, https://github.com/9001/asm

[ -e /z/asm.usb ] && sed -ri /:/d /etc/apk/repositories  # managed by wrepo

command -v bash >/dev/null || /etc/bin/apka -q bash 2>/dev/null >&2 || true
hash -r
. /etc/profile

[ -e /etc/profile.d/asm-paths.sh ] || { (
SEC=$(grep -qE ^root:: /etc/shadow || echo 1)
UKI=$(awk 'NR>1{next} {v=1} /modules=/{v=""} /apkovl=/{v=1} END{print v}' /proc/cmdline)
cat <<'EOF'
export AR=$(dirname /media/*/sm)
export AP=$(df -h $AR | awk 'NR==2{sub(/.*\//,"",$1);print$1}')
export AD=$(echo $AP | awk '/p[0-9]$/{sub(/p[0-9]$/,"");print;next} {sub(/[0-9]$/,"");print}')
export HOME=/root
EOF
echo export SHELL=$(command -v bash || command -v ash)
echo export CORES=$( (cat /proc/cpuinfo;echo) | awk -F: '{gsub(/[ \t]/,"")} /^physicalid:/{p=$2;n++} /^coreid:/{i=$2;n++} /^$/&&n{t[p"."i]=1;n=0} END {n=0;for(x in t)n++;print n}')
echo export SEC=$SEC
echo export UKI=$UKI
[ $UKI ] ||
  echo 'export PATH="$AR/sm/bin:$PATH"'

)>/etc/profile.d/asm-paths.sh
. /etc/profile.d/asm-paths.sh
}
hash -r
cd

# switch to shell after the first run
[ -e /dev/shm/once ] && {
  [ $SEC ] || exec $SHELL -l
  printf '\nthis console is disabled\n'
  sleep 80386
  exit 1
}
touch /dev/shm/once

cp -p /etc/bin/* /usr/local/bin/

# enable tty unless /proc/cmdline specifies secure
[ $SEC ] || passwd -u root 2>/dev/null

# start lo
command -v service >/dev/null &&
  service networking start || true

# load tty color scheme, announce we good
. /etc/profile.d/bifrost.sh
printf '\033[36m * %s ready\033[0m\n' "$(cat $AR/.alpine-release 2>/dev/null)"
printf '\033[s\033[H'; cat /etc/motd; printf '\033[u\033[?7h'
[ -e /z ] || { chvt 2; chvt 1; }

# switch to bash + add loggers
apka -q util-linux bash tar 2>/dev/null >&2 || true
[ $SHELL = /bin/bash ] &&
  sed -ri 's^/ash$^/bash^' /etc/passwd

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
  [ -e /etc/asm.pub ] || {
    printf '\033[33mbuilt with unsigned asm.sh; cannot verify integrity\033[0m\n'
    return
  }
  local f=$AR/sm/asm.sh
  printf ' verifying \r'
  apka -q openssl &&
  openssl dgst -sha512 -verify /etc/asm.pub -signature $f.sig $f >/dev/null &&
  true || return 1
}

[ $UKI ] && {
  sigchk || {
    printf '\n\033[31mABORT: asm.sh does not validate against its signature, or was not signed with the expected key\n\033[0m'
    if [ $SEC ]; then
      ebeep; exit 1
    else
      printf '\033[33mbut shell is allowed, so continuing anyways\033[0m\n'
      sleep 1
    fi
  }
}

# be noisy unless muted
beeps 40 2000 1000 &

# run the payload
s=$AR/sm/asm.sh
cmd="$SHELL $s"
logcfg=$(cat $AR/sm/log.cfg 2>/dev/null)
logcom=
logdir=
if [ "$logcfg" ] && apka -q util-linux; then
  for logcfg in $logcfg; do
    case $logcfg in
      *tty*)
        IFS=, read logcfg baud x < <(echo $logcfg,115200)
        [ -e /dev/$logcfg ] && stty -F /dev/$logcfg $baud && echo >/dev/$logcfg && logcom=$logcfg ||
          echo "comport unavailable: $logcfg"
        ;;
      1)
        if apka -q dosfstools 2>/dev/null; then
          fsck.vfat -a /dev/$AP >/dev/null
        else
          echo "note: skipping fsck.vfat (dosfstools unavailable)"
        fi
        mount -o remount,rw $AR && logdir=$AR
        ;;
      *)
        logdir=/media/$AD$logcfg
        mkdir -p $logdir
        mount /dev/$AD$logcfg $logdir || logdir=
        ;;
    esac
  done
  [ $logdir ] && touch $logdir/runlog.txt || logdir=
  while true; do sleep 5; killall -USR1 script 2>/dev/null; done &
fi
[ $logcom ] && [ $logdir ] && cmd="script -eqc \"$cmd;unlog\" /dev/$logcom"
if [ $logdir ]; then
  script -B $logdir/runlog.txt -T $logdir/runlog.pce -eqc "$cmd" && err= || err=$?
  setterm --dump --file $logdir/runlog.scr 2>/dev/null
elif [ $logcom ]; then
  script -eqc "$cmd;unlog" /dev/$logcom && err= || err=$?
else
  $cmd && err= || err=$?
fi
unlog

# success? exit
[ $err ] || {
  nohup beeps 70 523 784 1046 2>/dev/null &
  for a in a a a a; do sleep 0.05; [ -e nohup.out ] && break; done
  exit 0
}

# error; give shell
printf "\n$s: \033[31mERROR $err\033[0m\n"
apka -q tmux &
(ebeep; rmmod pcspkr 2>/dev/null) &
[ $SEC ] || exec $SHELL -l

