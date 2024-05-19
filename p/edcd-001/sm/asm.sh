#!/bin/bash
set -e

# static ip (for [n]etwork -> [s]tatic)
ip=10.1.2.51
mask=24

# sshd root password
pw=k

# screensaver
scrsv=1

. /etc/profile.d/edcd.sh

ESC=$'\033'
CYAN="$ESC[36m"
RST="$ESC[0m"

ask() { read -u1 -rp "$CYAN$1$RST" $2; }
ask1() { read -u1 -n1 -rp "$CYAN$1$RST" $2 && echo; }
mcat() { printf '\n\033[36m%79s\033[0m\n\033[A'|tr ' ' -; sed -r 's/$/ /;s/( )([a-zA-Z0-9])(\) )/\1'$CYAN'\2'$RST'\3/g'; }


mainmenu() {
    while true; do

        # nbsd-games wipe colorsheme; reapply
        local f=/etc/profile.d/hotdog.sh
        [ -e $f ] && . $f || . /etc/profile.d/bifrost.sh

        [ $nolm ] || mcat <<EOF
choose next action: $CYAN-------------$RST f) font
  n) start network + r0c          g) games    v) verify
  c) copyparty (choose n first)   L) lescue   x) exit to shell
  i) hop on irc (also needs n)    h) hotdog   k) shutdown
  s) start ssh-server (needs n)   w) wark     r) reboot
EOF
        nolm=
        t1=$(date +%s)
        read -u1 -n1 -t120 -rp $CYAN'sel> '$RST || {
            t2=$(date +%s)
            [ $((t2-t1)) -ge 110 ] && [ $scrsv ] &&
                unlog && xmas 1
        }
        unlog; echo
        case $REPLY in
            N|n) menu_net;;
            C|c) party;;
            I|i) irc;;
            S|s) start_ssh;;

            F|f) menu_font;;
            G|g) menu_games;;
            L|l) lescue;;
            H|h) nolm=1; hotdog;;
            W|w) nolm=1; printf '\033[A'; wark;;

            V|v) verify;;
            X|x) touch /dev/shm/nobeep; exit 1;;
            K|k) poweroff; exit 0;;
            R|r) reboot; exit 0;;
        esac
    done
}


setup_tmux() {
    tmux new -s 0 -d 2>/dev/null || true
    for n in {1..3}; do tmux neww -t 0:$n 2>/dev/null || true; done
    tmux killw -t 0:$1 2>/dev/null || true
    tmux neww -t 0:$1 -n $2
    tmux selectw -t 0:$1
    sleep 0.1  # cosmetic: bash init
}


showmotd() {
    printf '\033[s\033[2H'; cat /etc/motd
    printf '\033[1;999H\033[2D   \033[u\033[?7h'
    chvt 2; chvt 1
}


get_ip() {
    ip r | awk '/src /{print$NF;exit}'
}


menu_net() {
    read i1 i2 < <(echo $ip | sed -r 's/(.*)\./\1 /')
    mcat <<EOF
choose ip address:
  d) dynamic / dhcp
  s) static, starting from $i1.$i2
  i) static, starting from $i1.N
  w) wifi and/or advanced
EOF
    ask1 'sel> '
    echo $REPLY | grep -q i && {
        ask "$i1.?> " i2
        REPLY=s
    }
    echo
    case $REPLY in
        S|s) ip l set lo up
            (. /lib/libalpine.sh; available_ifaces) | tr ' ' '\n' |
            while read dev; do
                [ "$dev" ] || { echo "WARNING: no compatible network hardware found"; break; }
                [ $dev = lo ] && continue
                ip=$i1.$i2
                i2=$((i2+1))
                ip l set $dev up
                ip a a $ip/$mask dev $dev
                echo $dev = $ip /$mask
            done;;
        D|d)
            (sleep 1; rm -f /tmp/setup-interfaces*/w*.noconf) &
            echo "autoconfiguring network, pls wait..."
            printf '\033[1;30m'
            yes '' | setup-interfaces -r 2>&1 | sed -r "s/^(udhcpc:)/$RST\1/"
            printf '\033[0m';;
        W|w) setup-interfaces -r;;
        *) echo "bad input; aborting"; return;;
    esac

    log "ip: $(get_ip)"

    # start r0c in tmux so ^C wont affect it
    apka -q !pyc python3 tmux
    r0c --help 2>/dev/null >/dev/null
    setup_tmux 2 r0c
    tmux pipe-pane -t 0:2 -o "exec cat >>$(tty)"
    tmux send -t 0:2 "tps1; r0c -pw $(base64 /dev/urandom | tr -dc a-z | head -c9)" ENTER
    while true; do netstat -tln | grep -q ':23\b' && break; sleep 0.1; done
    sleep 0.5
    tmux pipe-pane -t 0:2
}


sfnt() { (cd /etc/cfnt; setfont $(ls -1 *.* | awk NR==${1:-1})); }
bfnt() { (cd /etc/cfnt/big; setfont $(ls -1 *.* | awk NR==${1:-1})); }
menu_font() {
    mcat <<EOF
select font:
  1) tiny   2) small   3) large   k) OK
EOF
    ask1 'sel>'
    case $REPLY in
        1) sfnt 2;;
        2) sfnt;;
        3) bfnt;;
        K|k) return;;
    esac
    printf '\n\n\n\n\033[4A'
    showmotd
    menu_font
}


menu_games() {
    mcat <<EOF
select game:
  2) 2048      s) solitaire   a) nbsd (21-in-1)
  n) nethack   t) treedude
EOF
    ask1 'sel>'
    case $REPLY in
        2) $AF/games/2048;;
        A|a) (cd /opt/nbsd || { apka -q zstd; tar -xvC/opt -f $AF/games/nbsd.tzst; }; cd /opt/nbsd && PATH=. ./nbsdgames);;
        N|n) apka -q nethack; nethack;;
        S|s) apka -q tty-solitaire; ttysolitaire --no-background-color;;
        T|t) apka -q treedude; treedude;;
    esac
}


start_ssh() {
    echo
    apk add -q openssh-server
    sed -ri 's/(Subsystem[^/]+sftp).*/\1 internal-sftp/' /etc/ssh/sshd_config
    keyfile=$AF/sm/authorized_keys
    if [ -e $keyfile ]; then
        log allowing $(grep ssh- $keyfile | wc -l) ssh-keys from $keyfile
        mkdir -p ~/.ssh
        cp -pv $keyfile ~/.ssh
    else
        awk '/^$/&&!o{print"The root password is '\'k\''";o=1}1' /etc/issue>/xx;cat /xx>/etc/issue
        sed -ri '$aPermitRootLogin yes' /etc/ssh/sshd_config
        printf '%s\n' "$pw" "$pw" | passwd >/dev/null
        killall getty || true
    fi
    service sshd start
    ip=$(get_ip)
    [ $ip ] &&
        log "ssh root@$ip (password is 'k')" ||
        log "ssh server up, press n to start networking"
}


irc() {
    ask 'irc-nick> ' nick
    mcat <<EOF
choose ircnet:
  d) dalnet   o) oftc
  e) efnet    q) quakenet
  i) ircnet   r) rizon
  L) libera   u) undernet
EOF
    ask1 'sel> '
    case $REPLY in
        D|d) inet=irc.dal.net;;
        E|e) inet=irc.homelien.no;;
        I|i) inet=irc.ircnet.com;;
        L|l) inet=irc.libera.chat;;
        O|o) inet=irc.oftc.net;;
        Q|q) inet=irc.quakenet.org;;
        R|r) inet=irc.rizon.net;;
        U|u) inet=irc.undernet.org;;
        *) echo "bad input; aborting"; return;;
    esac

    apka -q irssi

    # quakenet klines anyone with username 'root'
    mkdir -p ~/.irssi && echo "settings={core={real_name="edcd";user_name="edcd";};};" > ~/.irssi/config

    scrsv=
    setup_tmux 3 irc
    tmux send -t 0:3 "tps1; irssi -n '$nick' -c '$inet'" ENTER
    tmux a -t 0
}


lescue() {
    apka -q !pyc mpv || return
    local e=/dev/shm/mpv.log
    for vo in drm tct; do
        mpv --loop=inf --log-file=$e --vo=$vo $AF/lescue.webm || true
        grep -qE 'Errors when loading file|Error opening.* selected video_out|Failed to create DRM' $e || break
    done
}


verify() {
    local nf=$(wc -l <$AF/B2SUMS)
    apka -q coreutils pv || return
    if apka -q xorriso; then
        echo "now checking CD for damage, using optimal read order..." >&2
        xorriso -indev stdio:/dev/$AD -find . -exec report_lba 2>&1 | sort -nk6,6 | tee /dev/shm/cdfo1 | awk -F\' '/^File data lba: +0/{print substr($2,3)}' >/dev/shm/cdfo
        cat /dev/shm/cdfo $AF/B2SUMS | awk '
            /^[0-9a-f]{16,128} [ *]/{h=$1;sub(/[^ ]+ ./,"");f=$0;chk[f]=h;if(!seen[f]){seen[f]=1;ord[nf++]=f};next}
            /./{seen[$0]=1;ord[nf++]=$0}
            END{for(a=0;a<nf;a++){f=ord[a];sum=chk[f];if(sum){printf"%s  %s\n",sum,f}}}
        ' | (cd $AF; b2sum -c -) | tee /dev/shm/cdck | pv -ls$nf
    else
        echo "now checking CD for damage, using the slower fallback..." >&2
        (cd $AF; b2sum -c B2SUMS)
    fi |
    grep -vE ': OK$' && msg="37;41m OH NO VERIFICATION FAILED" || msg="30;42m ok good"
    printf '\033[1;%s \033[0m\n' "$msg"
}


wark() {
    n=$(($RANDOM%64+1)); while [ $n -gt 0 ]; do n=$((n-1)); printf '\033[1;3%d;4%dm wark ' $(($RANDOM%8)) $(($RANDOM%8)); done; printf '\033[0m\033[K\n'
}


hotdog() {
    local d=/etc/profile.d
    local b=$d/bifrost.sh h=$d/hotdog.sh
    if [ -e $h ]; then rm $h; . $b; echo disengaged...; else cat >$h <<'EOF'
printf '\033]P0000000\033]P1ff0000\033]P2ffff00\033]P3ffff00\033]P4ff0000\033]P5ff0000\033]P6ffff00\033]P7ffffff'
printf '\033]P8ff0000\033]P9ff0000\033]Paffff00\033]Pbffff00\033]Pcff0000\033]Pdff0000\033]Peffff00\033]Pfffffff'
printf '\033\\\033[J'
EOF
    chmod 755 $h; . $h; echo ENGAGED
    fi
    showmotd
}


party() {
    local n v ds pid args uname acct
    if ps aux | grep -q 'rty-sfx\.py'; then
        tmux selectw -t 0:1
        tmux a -t 0
        return
    fi

    # keep first; thrashes the laser
    mcat <<EOF
configure filesystem access:
  1) share all local disks (usb/hdd)
  2) select from a list
  3) only cdrom (no persistent storage)
EOF
    while true; do
        ask1 'choose 1~3> '
        case $REPLY in
            1) v=y; ds=; break;;
            2) v=y; ds=y; break;;
            3) v=; break;;
        esac
    done
    [ $v ] && {
        echo scanning filesystems...
        [ $ds ] && hdr=stderr || hdr=null
        lsblk -o SIZE,KNAME,SUBSYSTEMS,TYPE,FSTYPE,LABEL | awk '
            NR==1 {print" disk#  "$0>"/dev/'$hdr'";next}
            $1!="0B" && / (disk|part) +[^ ]/ && $2!="'$AD'"
        ' >/dev/shm/harddiskar

        grep -qE .. /dev/shm/harddiskar || {
            echo "no disks detected! will only share files from cdrom"
            ds=
        }
        if [ $ds ]; then
            cat -n /dev/shm/harddiskar
            ask 'space-separated list of disk# to share> '
            rm -f /dev/shm/utvalg
            for n in $REPLY; do
                awk NR==$n /dev/shm/harddiskar >>/dev/shm/utvalg
            done
        else
            mv /dev/shm/harddiskar /dev/shm/utvalg
        fi
        rmdir /media/* 2>/dev/null || true
        awk '{print$2}' /dev/shm/utvalg | while IFS= read -r d; do
            mkdir /media/$d && mount /dev/$d /media/$d || true
        done
    }

    mcat <<EOF
configure features:
  1) both FFmpeg and Pillow (good choice)
  2) just enable FFmpeg for music, tags, video thumbs
  3) just enable Pillow for thumbnails
  4) no, just copyparty please
EOF
    while true; do
        ask1 'choose 1~4> '
        case $REPLY in
            1) have_ffmpeg=1; v='py3-pillow ffmpeg';;
            2) have_ffmpeg=1; v='ffmpeg';;
            3) have_ffmpeg=;  v='py3-pillow';;
            4) have_ffmpeg=;  v='';;
            *) continue;
        esac
        break
    done

    # ensure optimal cd read order regardless of selection
    ( ( utime >/dev/shm/pt1; apka !pyc tmux python3 ntfs-3g hfsfuse ; for p in $v ; do apka !pyc $p ; done
    ) 2>&1 | while IFS= read -r x; do log -b "$x"; done; utime >/dev/shm/pt2) & pid=$!
    #(utime >/dev/shm/pt1; apka !pyc tmux python3 ntfs-3g $v 2>&1 | while IFS= read -r x; do log -b "$x"; done; utime >/dev/shm/pt2) & pid=$!

    mcat <<EOF
configure indexing:
  1) uploads only (makes them resumable and searchable)
  2) scan all disks and index all files within
  3) ...and also make music searchable by title/artist
  4) no
EOF
    while true; do
        ask1 'choose 1~4> '
        case $REPLY in
            1) e2d='-e2t';;
            2) e2d='-e2dsa -e2t';;
            3) e2d='-e2dsa -e2ts';;
            4) e2d='--no-snap --hist /dev/shm';;
            *) continue;;
        esac
        break
    done

    mcat <<EOF
configure password:
  1) no
  2) wark
  3) custom
EOF
    while true; do
        ask1 'choose 1~3> '
        case $REPLY in
            1) uname=; acct=;;
            2) uname=,u; acct='-a u:wark'; wark;;
            3) uname=,u; ask 'password> '; acct="-a u:$REPLY";;
            *) continue;;
        esac
        break
    done

    mcat <<EOF
configure permissions:
  1) read-write-move-delete
  2) read-write
  3) read
EOF
    while true; do
        ask1 'choose 1~3> '
        case $REPLY in
            1) axs='A';;
            2) axs='rw';;
            3) axs='r';;
            *) continue;;
        esac
        break
    done

    echo 'still unpacking deps, pls wait ... watch the top bar'
    wait $pid 2>/dev/null || true
    printf '\033[A\033[J'

    rmdir /media/* 2>/dev/null || true

    args=(-v /media::$axs$uname)
    for v in /media/*; do
        [ $v = $AF ] && {
            # usually "cdrom" or "sr0"; assume read-only fs
            args+=("-v $v:${v:7}:r$uname:c,e2ds,d2ts,fat32,nohash=.:c,dbd=acid:c,hist=~/.cdhist")
            cp -pR $v/.hist ~/.cdhist || true
            continue
        }
        [ -e "$v" ] && args+=("-v $v:${v:7}:$axs$uname")
    done

    [ $have_ffmpeg ] &&
        args+=("--qrl=${AF##*/}/chiptunes/#af-09893ef5")

    cat >/partycmd <<EOF
set -x
tmux set -g status-right "#(ip r | awk '/src /{print\\\$NF;exit}'), %Y-%m-%d, %H:%M:%S"
python3 $AF/edware/copyparty-sfx.py \
    --ftp=21 --tftp=69 -p=80,443,3923 --au-vol=100 \
    --qrz=1 --qrp=1 --qri=. --ver --no-crt --no-dedup \
    -z -ed -emp --exp --th-clean=0 --no-mutagen \
    $acct $e2d ${args[@]} || true
EOF

    scrsv=
    setup_tmux 1 cpp
    tmux send -t 0:1 "tps1; /bin/bash /partycmd" ENTER
    tmux a -t 0
}

# intel-uhd-graphics <700 doesn't render past 3840x2117
(fbset 2>&1) | awk '$1=="geometry" && $4>2560 && $5>1920 {r=1} END {exit r-1}' && fbset -xres 2560 -yres 1920

# not necessary since tinyalsa is in apkovl:
#while ps | grep -q 'b[e]eps'; do sleep 0.1; done

#blkid -po export /dev/$AP
#vol="$(grep -o EDCD_001. $AF/efi/boot/bootx64.efi)"
vol="$(lsblk -dino LABEL /dev/$AP 2>/dev/null || echo no)"
if echo "$vol" | grep -qE ^EDCD_001; then
    n=$(printf %d 0x$(echo ${vol:8} | xxd -g1 | awk '{print$2}'))
    msg="[1;30;42m hello from EDCD-001 copy #$((n-64)) of 20 :^)"
else
    msg="[1;37;41m /!\\ counterfeit copy of EDCD-001 /!\\"
fi
printf '\033[2A\033[J\033%s \033[0m\n' "$msg"

(apka gpm && service gpm start) >/dev/null 2>&1 &

mainmenu
