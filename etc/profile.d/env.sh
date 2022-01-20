# https://ocv.me/dot/.bashrc
bslcb() {
	local RETVL=$? BSLMT=']'
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

shopt -s histappend
shopt -s checkwinsize

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
strapmod() {
	cd /root && tar -xf $AR/the.apkovl.tar.gz && cd etc
}
strapsave() {
	(cd /root && mount -o remount,rw $AR && tar -czf $AR/the.apkovl.tar.gz etc && echo ok)
}

if [ -d /etc/apk/ ] ; then
	alias tmux='TERM=rxvt-256color tmux -2u'
	[ "x$TERM" == "xrxvt" ] && export TERM=rxvt-256color
	[ "x$TERM" == "xxterm" ] && export TERM=rxvt-256color
	alias apk='/sbin/apk --force-non-repository'
	alias mc='/usr/bin/mc -S /usr/share/mc/skins/nicedark.ini'
else
	alias tmux='TERM=screen-256color tmux'
fi

alias q='kill -9 $$'
alias a='tmux attach || tmux'

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
