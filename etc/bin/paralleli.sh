# paralleli.sh - kinda like GNU Parallel but not GNU
# v1.1, 2020-06-18, ed <irc.rizon.net>, MIT-Licensed
# https://ocv.me/dev/?paralleli.sh
#
# breaking changes in v1.1:
# - no longer executes as a program but must be sourced,
#   will define the `par' function which is what you want
#   (this permits using another function as the target)

_par_test()
{
	rm -rf /dev/shm/par
	mkdir /dev/shm/par
	for x in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16
	do
		cp -pv /usr/share/qemu/edk2-arm-code.fd /dev/shm/par/fn\ i$x
	done
}

# unit test usage:
# . ~/dev/paralleli.sh && _par_test && find /dev/shm/par -type f | sort | par 4 xz -ze7 "\$fn"
# fun() { xz -ze7 "$1"; }; _par_test && find /dev/shm/par -type f | sort | par 4 fun "\$fn"

# command eval test:
# echo memes | par 1 printf '[%s] ' "lorem" "ipsum dolor" "\$fn" "\\\$fn" "sit amet" 'consectetur "adipiscing" elit' "Integer 'id diam' \"in ipsum\""

# smoke test: verify files before and after
# find -maxdepth 1 | cut -c3- | sort -n | grep -E '^[0-9]+\.[0-9]{8,12}$' | xargs md5sum > sum.1
# find -maxdepth 1 | cut -c3- | sort -n | grep -E '^[0-9]+\.[0-9]{8,12}$' | par 8 xz -ze9 "\$fn" 
# find -maxdepth 1 | cut -c3- | sort -n | grep -E '^[0-9]+\.[0-9]{8,12}.xz$' | while IFS= read -r x; do xz -dc < "$x" | md5sum; done | tee sum.2
# for x in 1 2; do cut -c-32 < sum.$x | md5sum; done


par() {
	local q=
	[ "$1" = -q ] && q=q && shift
	
	local jobs=$1
	printf '%s\n' "$1" |
	grep -qE '^[0-9]+$' ||
		jobs=0

	[ $jobs -gt 0 ] && [ "$2" != "" ] ||
	{
		printf "
\033[35mneed argument 1:\033[0m
  number of threads to use

\033[35mneed argument 2:\033[0m
  command to execute where \\\$fn will be filename;
  \033[33mall variables are expanded before being passed in,
  prevent expansion by escaping $ to \\$

\033[36mexample:
  find ~/Documents -name '*.txt' | sort |
    nice $0 4 xz -ze9 \"\\\$fn\"\033[0m

" >&2
		return 1
	}


	local cmd=""
	shift
	for x in "$@"
	do
		cmd="$cmd\"$(
			printf '%s\n' "$x" |
			sed -r 's/"/\\"/g'
		)\" "
	done

	printf "\033[33m\
thr: \033[1;37m%d\033[0;33m
cmd: \033[1;37m%s\033[0m
" "$jobs" "$cmd" >&2

	local nbusy=0
	local jobctr=0
	local td=$(mktemp -d)
	while IFS='\n' read -r fn
	do
		[ -e $td/err ] &&
			break
		
		while [ $nbusy -ge $jobs ]
		do
			nbusy=0
			for x in $td/j*
			do
				[ "$x" == "$td/j*" ] ||
					nbusy=$((nbusy+1))
			done
			sleep 0.01
		done
		
		nbusy=$((nbusy+1))
		jobctr=$((jobctr+1))
		mkdir $td/j$jobctr
		[ $q ] || printf '\033[36m[+] start %04d: %s\033[0m\n' $jobctr "$fn" >&2
		{
			# the task to perform
			eval "$cmd" < /dev/null ||
			{
				printf '\033[1;31mcommand returned %s for job #%s, file [%s]\033[0m\n' \
					$? $jobctr "$fn" >&2
				
				mkdir -p $td/err
			}
			
			[ $q ] || printf '\033[36m[-]   end %04d: %s\033[0m\n' $jobctr "$fn" >&2
			rmdir $td/j$jobctr
		} &
	done

	[ $q ] || printf '\033[36m[+] stdin empty\033[0m\n' >&2

	# cannot use wait since the while loop is a subshell itself,
	# which also means we cannot see variable modifications within
	while true
	do
		nbusy=0
		for x in $td/j*
		do
			[ "$x" == "$td/j*" ] ||
				nbusy=$((nbusy+1))
		done
		
		[ $nbusy -eq 0 ] &&
			break ||
			sleep 0.1
	done

	rm -rf $td
	[ $q ] || printf '\033[36m[+] done\033[0m\n' >&2
}
