# https://ocv.me/dot/.bashrc
bslcb() {
	local RETVL=$? BSLMT=']' a b
	[ -z "$BSLNFC" ] || {
		read -r a b < <(history 1)
		BSLMT="$a] $b [$RETVL]"
	}
	BSLMT="$(date +'%Y-%m-%d, %H:%M:%S') [$$-$BSLMT"
	printf '%s\n' "$BSLMT" >> ~/.bash.log

	[ -z "$BSLNFC" ] || {
		[ $RETVL -eq 0 ] && echo ||
			echo -e "\n\033[1;91mError Code:\033[0;1m $RETVL\033[0m"

		bash -c 'stat .' 2>&1 | grep -qE 'No such file or directory|Links: 0[ $]' && {
			echo -e "\033[1;93mWARNING\033[0m: Current directory does not exist anymore."
			cd -- "$BSLNFC" 2>/dev/null &&
				echo -e "\033[1;92mNOTICE:\033[0m Recovered pwd:  $(pwd)" ||
				echo -e "\033[1;91mALERT:\033[0m Could not recover pwd"
		}
	}
	BSLNFC="$PWD"
}
PROMPT_COMMAND=bslcb

HISTSIZE=10000
HISTFILESIZE=10000
HISTCONTROL=ignoreboth

shopt -s histappend 2>/dev/null
shopt -s checkwinsize 2>/dev/null

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
	cd /root && tar -xf $AR/the.apkovl.tar.gz && cd etc
}
[ $UKI ] || strapsave() {
	(cd /root && mount -o remount,rw $AR && tar -czf $AR/the.apkovl.tar.gz etc && sync && (fstrim $AR 2>/dev/null || true) && echo ok)
}
rw() {
	mount -o remount,rw $AR
	pwd | grep -q $AR || cd $AR/sm
}

if [ -d /etc/apk/ ] ; then
	alias tmux='TERM=rxvt-256color tmux -2u'
	[ "x$TERM" == "xrxvt" ] && export TERM=rxvt-256color
	[ "x$TERM" == "xxterm" ] && export TERM=rxvt-256color
	alias apk='/sbin/apk --force-non-repository --wait 10'
	alias mc='[ -e /usr/bin/mc ] || apka mc; /usr/bin/mc -S /usr/share/mc/skins/nicedark.ini'
	alias i='apk add'
else
	alias tmux='TERM=screen-256color tmux'
fi
for c in bmon htop lshw ncdu ranger sshfs vim; do
	alias $c="unalias $c; which $c >/dev/null || apka $c; $c"
done

alias q='kill -9 $$'
alias a='tmux attach || tmux || { apka tmux && tmux; }'
alias yssh='ssh -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no'

PS1="\
\[\033[90m\]-\
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
