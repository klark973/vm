# vm-opts -- parse optional arguments.
#
# This file is covered by the GNU General Public License
# version 3, or (at your option) any later version, which
# should be included with sources as the file COPYING.
#
# Copyright (C) 2023, Leonid Krivoshein <klark@altlinux.org>
#
saved_CLR_ERR="$CLR_ERR"; CLR_ERR=
s_opts="+D:H:S:a:c:d:f:i:km:np:r:s:t:uvh"
l_opts="disks:,sockets:,arch:,cores:,hostdir:,forward:,host:,image:,keep-cd"
l_opts="$l_opts,no-keep-cd,memory:,no-colors,port:,rescue:,share:,timeout:"
l_opts="$l_opts,uefi,no-uefi,use-tmpdir,inplace,no-tmpdir,version,help"
l_opts=$(getopt -n "$PROG" -o "$s_opts" -l "$l_opts" -- "$@") ||
	fatal "Invalid command line usage, try '$PROG -h' for more details."
eval set -- "$l_opts"
unset s_opts l_opts
#
while [ $# -gt 0 ]; do
	case "$1" in
	-D|--disks)
		DISKS="${2:-}"
		shift
		;;
	-H|--host)
		HOST="${2:-}"
		shift
		;;
	-S|--sockets)
		SOCKETS="${2:-}"
		shift
		;;
	-a|--arch)
		ARG_ARCH="${2:-}"
		case "$ARG_ARCH" in
		i?86|pentium|athlon)
			ARG_ARCH=i386
			;;
		esac
		shift
		;;
	-c|--cores)
		CORES="${2:-}"
		shift
		;;
	-d|--hostdir)
		HOSTDIR="$(realpath -- "${2:-$HOSTDIR}")"
		if [ -s "$HOSTDIR/.host/guest.env" ]; then
			. "$HOSTDIR/.host/guest.env"
		elif [ -s "$HOSTDIR/guest.env" ]; then
			. "$HOSTDIR/guest.env"
		fi
		shift
		;;
	-f|--forward)
		case "${2:-}" in
		"")	FORWARDS=
			;;
		hostfwd=*|guestfwd=*)
			FORWARDS="${FORWARDS:+$FORWARDS,}$2"
			;;
		*)	FORWARDS="${FORWARDS:+$FORWARDS,}hostfwd=$2"
			;;
		esac
		shift
		;;
	-i|--image)
		[ -z "${2:-}" ] ||
			ARG_IMAGES=( "${ARG_IMAGES[@]}" "$2" )
		shift
		;;
	-k|--keep-cd)
		KEEPCD=1
		;;
	-m|--memory)
		MEMORY="${2:-}"
		shift
		;;
	-n|--no-colors)
		CLR_NORM=
		CLR_BOLD=
		CLR_LC1=
		CLR_LC2=
		CLR_OK=
		CLR_WARN=
		saved_CLR_ERR=
		;;
	-p|--port)
		PORT="${2:-}"
		shift
		;;
	-r|--rescue)
		RESCUE="${2:-}"
		shift
		;;
	-s|--share)
		[ -z "${2:-}" ] && SHARES=() ||
			SHARES=( "${SHARES[@]}" "$2" )
		shift
		;;
	-t|--timeout)
		TIMEOUT="${2:-}"
		shift
		;;
	-u|--uefi)
		ARG_UEFI=1
		;;
	--no-keep-cd)
		KEEPCD=
		;;
	--no-uefi)
		ARG_UEFI=0
		;;
	--use-tmpdir)
		INPLACE=
		;;
	--no-tmpdir|--inplace)
		INPLACE=1
		;;
	-v|--version)
		printf "%s %s\n" "$PROG" "1.0"
		exit 0
		;;
	-h|--help)
		. "$LIBEXEC"/vm-help.sh
		;;
	--)	shift
		break
		;;
	*)	break
		;;
	esac
	shift
done

# There're unchangeble only
readonly CLR_NORM="$CLR_NORM"
readonly CLR_BOLD="$CLR_BOLD"
readonly CLR_LC1="$CLR_LC1"
readonly CLR_LC2="$CLR_LC2"
readonly CLR_OK="$CLR_OK"
readonly CLR_WARN="$CLR_WARN"
readonly CLR_ERR="$saved_CLR_ERR"
readonly TIMEOUT="$TIMEOUT"
readonly ARG_ARCH="$ARG_ARCH"
readonly ARG_UEFI="$ARG_UEFI"
readonly ARG_IMAGES=( "${ARG_IMAGES[@]}" )
unset saved_CLR_ERR
