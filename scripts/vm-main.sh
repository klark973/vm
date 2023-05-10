# vm-main.sh -- main script and entry point for any command.
#
# This file is covered by the GNU General Public License
# version 3, or (at your option) any later version, which
# should be included with sources as the file COPYING.
#
# Copyright (C) 2023, Leonid Krivoshein <klark@altlinux.org>
#
set -e
set -f
set -u

# Default values
#
INPLACE=
UEFI=
ISO=
KEEPCD=
SOCKETS=1
CORES=2
MEMORY=2G
PORT=5900
HOST=localhost
FORWARDS=
DISKS="AHCI=30G"
SHARES=( "mirror:@MIRROR@" "in:@HOSTDIR@" "out:rw:@DATADIR@" )
MEDIA_MIRROR=
MEDIA_STORAGE=

# Console colors
#
CLR_NORM='\033[00m'
CLR_BOLD='\033[01;37m'
CLR_LC1='\033[00;36m'
CLR_LC2='\033[01;35m'
CLR_OK='\033[00;32m'
CLR_ERR='\033[01;31m'
CLR_WARN='\033[01;33m'

# Run-time computed values
SSHKEYS=( "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/id_rsa.pub" )
HOSTDIR="$(realpath -- "$PWD")"
readonly PROG="${0##*/}"
QEMUARCH="$(uname -m)"
case "$QEMUARCH" in
i?86|pentium|athlon)
	QEMUARCH=i386
	;;
esac

# Override default values
[ ! -s "/etc/$PROG.conf" ] ||
	. "/etc/$PROG.conf"
[ ! -s "$HOME/.config/$PROG.conf" ] ||
	. "$HOME/.config/$PROG.conf"
if [ -s "$HOSTDIR/.host/guest.env" ]; then
	. "$HOSTDIR/.host/guest.env"
elif [ -s "$HOSTDIR/guest.env" ]; then
	. "$HOSTDIR/guest.env"
fi

# Other run-time computed values (can't be overrided)
#
readonly PROFILES="${PROFILES:-$HOME/$PROG}"
readonly LIBEXEC="${LIBEXEC:-$PROFILES/scripts}"
readonly OVMF_CODE=/usr/share/OVMF/OVMF_CODE.fd
readonly OVMF_VARS=/usr/share/OVMF/OVMF_VARS.fd
RESCUE="rescue-$QEMUARCH"
MEDIA=
WORKDIR=
IMAGES=()

# Separate stored command line arguments
#
TIMEOUT=
ARG_ARCH=
ARG_UEFI=
ARG_IMAGES=()

# Bootstrap
. "$LIBEXEC"/vm-func.sh
. "$LIBEXEC"/vm-opts.sh

# Locate working directory
if [ -n "$INPLACE" ]; then
	WORKDIR="$HOSTDIR"
elif [ -L "$HOSTDIR/.work" ] && [ -d "$HOSTDIR/.work" ]; then
	WORKDIR="$(realpath -- "$HOSTDIR"/.work)"
elif [ -L "$HOSTDIR/.host" ] && [ -d "$HOSTDIR/.host" ]; then
	WORKDIR="$HOSTDIR"
	HOSTDIR="$(realpath -- "$WORKDIR"/.host)"
fi

# Sanity check before run
[ "$HOSTDIR" != "$LIBEXEC" ] && [ "$HOSTDIR" != "$PROFILES" ] ||
	fatal "Invalid host directory: '$HOSTDIR'."

# By default just run Virtual Machine
if [ "$#" = 0 ]; then
	exec_cmd run
	exit 0
elif [ "$#" = 1 ] && [ ! -s "$LIBEXEC/vm-cmd-$1.sh" ]; then
	if [ -z "$1" ] || [ "${1:0:1}" != "@" ] || [ ! -s "$LIBEXEC/vm-cmd-${1:1}.sh" ]; then
		exec_cmd run "$1"
		exit 0
	fi
fi

# Batch commands
while [ "$#" -gt 0 ]; do
	cmd_curr="$1"; shift
	[ -z "$cmd_curr" ] || [ "${cmd_curr:0:1}" != "@" ] ||
		cmd_curr="${cmd_curr:1}"
	[ -n "$cmd_curr" ] && [ -s "$LIBEXEC/vm-cmd-$cmd_curr.sh" ] ||
		fatal "Too many arguments, try '$PROG -h' for more details."

	. "$LIBEXEC/vm-cmd-$cmd_curr.sh"

	min_args="$(vm_cmd_"$cmd_curr"_args |cut -f1 -d:)"
	[ "$#" -ge "$min_args" ] ||
		fatal "Not enough arguments, try '$PROG -h' for more details."
	max_args="$(vm_cmd_"$cmd_curr"_args |cut -f2 -d:)"
	max_args="$(( $max_args - $min_args ))"
	cmd_args=()

	# Read required arguments
	while [ "$min_args" != 0 ]; do
		cmd_args=( "${cmd_args[@]}" "$1" )
		min_args="$(( $min_args - 1 ))"
		shift
	done

	# Read optional arguments
	while [ "$#" != 0 ] && [ "$max_args" != 0 ]; do
		[ -z "$1" ] || [ "${1:0:1}" != "@" ] ||
		[ ! -s "$LIBEXEC/vm-cmd-${1:1}.sh" ] ||
			break
		[ -z "$1" ] || [ "${1:0:1}" = "@" ] ||
		[ ! -s "$LIBEXEC/vm-cmd-$1.sh" ] ||
			break
		cmd_args=( "${cmd_args[@]}" "$1" )
		max_args="$(( $max_args - 1 ))"
		shift
	done

	unset min_args max_args
	exec_cmd "$cmd_curr" "${cmd_args[@]}"
	unset cmd_curr cmd_args
done

exit 0
