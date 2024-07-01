alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

wt() {
	printf '\033]0;%s\033\\' "$*"
}
[ $UKI ] || strapmod() {
	cd /root && tar -xf $AF/the.apkovl.tar.gz && cd etc
}
[ $UKI ] || strapsave() {
	(cd /root && mount -o remount,rw $AF && tar -czf $AF/the.apkovl.tar.gz etc && sync && (fstrim $AF 2>/dev/null || true) && echo ok)
}
rw() {
	mount -o remount,rw $AF
	pwd | grep -q $AF || cd $AF/sm
}
sfnt() {
	(cd /etc/cfnt; setfont $(ls -1 *.* | awk NR==${1:-1}))
}
bfnt() {
	(cd /etc/cfnt/big; setfont $(ls -1 *.* | awk NR==${1:-1}))
}

if [ -d /etc/apk/ ] ; then
	[ "x$TERM" == "xrxvt" ] && export TERM=rxvt-256color
	[ "x$TERM" == "xxterm" ] && export TERM=rxvt-256color
	alias mc='/usr/bin/mc -S /usr/share/mc/skins/nicedark.ini'
fi

alias q='kill -9 $$'
alias a='tmux attach || tmux || { apka tmux && tmux; }'

PS1="\
\[\033[90;40m\]-\
\[\033[95m\]\$?\
\[\033[90m\]-\
\[\033[91m\]\$(date +%H%M%S)\
\[\033[90m\]-\
\[\033[93m\]\u\
\[\033[90m\]-\
\[\033[92m\]\h\
\[\033[90m\] <\
\[\033[94m\]\w\
\[\033[90m\]> \
\[\033[0m\]\n"

true
