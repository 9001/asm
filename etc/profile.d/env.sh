# https://ocv.me/dot/.bashrc
bslcb() {
	local RETVL=$? BSLMT=']'
	[ -z "$BSLNFC" ] || {
		read a b < <(history 1)
		BSLMT="$a] $b [$RETVL]"
	}
	BSLMT="$(date +'%Y-%m-%d, %H:%M:%S') [$$-$BSLMT"
	printf '%s\n' "$BSLMT" >> ~/.bash.log

	[ -z "$BSLNFC" ] || {
		[ $RETVL -eq 0 ] && echo ||
			echo -e "\n\033[1;31mError Code:\033[0;1m $RETVL\033[0m"

		bash -c 'stat .' 2>&1 | grep -qE 'No such file or directory|Links: 0[ $]' && {
			echo -e "\033[1;33mWARNING\033[0m: Current directory does not exist anymore."
			cd -- "$BSLNFC" 2>/dev/null &&
				echo -e "\033[1;32mNOTICE:\033[0m Recovered pwd:  $(pwd)" ||
				echo -e "\033[1;31mALERT:\033[0m Could not recover pwd"
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
else
	alias tmux='TERM=screen-256color tmux'
fi

alias q='kill -9 $$'
alias a='tmux attach || tmux'

PS1="\
\[\033[1;30m\]-\
\[\033[1;35m\]\$?\
\[\033[1;30m\]-\
\[\033[1;31m\]\$(date +%H%M%S)\
\[\033[1;30m\]-\
\[\033[1;33m\]\u\
\[\033[1;30m\]-\
\[\033[1;32m\]\h\
\[\033[1;30m\] <\
\[\033[1;34m\]\w\
\[\033[1;30m\]> \
\[\033[0m\]\n"

true
