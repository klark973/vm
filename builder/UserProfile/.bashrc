# .bashrc

# Source global definitions
if [ -r /etc/bashrc ]; then
	. /etc/bashrc
fi

# Is it interactive shell?
if [ -z "${-##*i*}" ]; then
	# Setup bash environment
	export PATH="$HOME/bin:$PATH"
	export EDITOR="/usr/bin/mcedit"
	export USERNAME="${HOME##*/}"
	export LOGNAME="$USERNAME"
	export USER="$USERNAME"
	export LANG="en_US.UTF-8"
	export LC_ALL="en_US.UTF-8"
	export TMPDIR="/tmp/.private/$USERNAME"
	export PS1='\[\033[01;32m\]\u@\[\033[01;31m\]\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

	# Create hasher work directory
	mkdir -p -m 0755 -- "$TMPDIR"/hasher

	# Banner
	echo "Welcome to ALT Sisyphus builder!"
	echo -n "Current time is: "
	date
	echo
fi
