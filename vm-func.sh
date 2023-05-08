# vm-func.sh -- supplimental functions.
#
# This file is covered by the GNU General Public License
# version 3, or (at your option) any later version, which
# should be included with sources as the file COPYING.
#
# Copyright (C) 2023, Leonid Krivoshein <klark@altlinux.org>
#

fatal() {
	printf "${CLR_ERR}*** %s fatal: %s${CLR_NORM}\n" "$PROG" "$*" >&2
	exit 1
}

exec_cmd() {
	local arg first=1 cmd="$1"; shift

	. "$LIBEXEC/vm-cmd-$cmd.sh"

	printf "${CLR_BOLD}*** Executing command: ${CLR_WARN}%s${CLR_BOLD}(" "$cmd"

	for arg in "$@"; do
		[ -n "$first" ] ||
			printf ", "
		printf "'%s'" "$arg"
		first=
	done

	printf ")...${CLR_NORM}\n"
	"vm_cmd_${cmd}_exec" "$@"
}

exec_cmd_silently() {
	local cmd="$1"; shift

	. "$LIBEXEC/vm-cmd-$cmd.sh"

	"vm_cmd_${cmd}_exec" "$@"
}

check_requires() {
	local i

	for i in "qemu-system-$QEMUARCH" qemu-img pigz unpigz; do
		which -- "$i" >/dev/null 2>&1 ||
			fatal "Programm '$i' is not installed."
	done
}

check_external_media() {
	local i

	if [ -z "$MEDIA" ] && [ "${#SHARES[@]}" != 0 ]; then
		for i in "${SHARES[@]}"; do
			if [ -z "${i##*:@MIRROR@}" ]; then
				. check-media
				return 0
			fi
		done
	fi

	if [ -z "$MEDIA" ] && [ "${#IMAGES[@]}" != 0 ]; then
		for i in "${IMAGES[@]}"; do
			if [ -z "${i##@MEDIA@/*}" ]; then
				. check-media
				return 0
			fi
		done
	fi

	if [ -z "$MEDIA" ] && [ "${#ARG_IMAGES[@]}" != 0 ]; then
		for i in "${ARG_IMAGES[@]}"; do
			if [ -z "${i##@MEDIA@/*}" ]; then
				. check-media
				return 0
			fi
		done
	fi
}

locate_cdrom() {
	local base="$1" msgpfx="$2"

	if [ -s "$ISO" ]; then
		CDROM="$(realpath -- "$ISO")"
	elif [ -s "$base/$ISO" ]; then
		CDROM="$(realpath -- "$base/$ISO")"
	else
		[ -n "$MEDIA" ] ||
			. check-media
		[ -s "${MEDIA}${MEDIA_STORAGE}/$ISO" ] ||
			fatal "$msgpfx ISO-image not found: '$ISO'."
		CDROM="$(realpath -- "${MEDIA}${MEDIA_STORAGE}/$ISO")"
	fi
}

create_workdir() {
	export TMPDIR="${TMPDIR:-/tmp}"

	if [ -z "$INPLACE" ] && [ -z "$WORKDIR" ]; then
		WORKDIR="$(mktemp -dt -- "$PROG-XXXXXXXX.tmp")" ||
			fatal "Couldn't create a working directory."
		chmod 0700 -- "$WORKDIR"
		ln -snf -- "$HOSTDIR" "$WORKDIR"/.host
		ln -snf -- "$WORKDIR" "$HOSTDIR"/.work
	fi

	[ -n "$WORKDIR" ] ||
		WORKDIR="$HOSTDIR"
	mkdir -p -m 0755 -- "$WORKDIR"/.out
}

vm_build_top() {
	local cpu=kvm64

	# CPU architecture
	case "$QEMUARCH" in
	i386) cpu=kvm32;;
	esac

	# Spice defaults
	SPICE="ipv4=on,ipv6=off,disable-ticketing=on"

	# Is client at the remote side?
	case "$HOST" in
	"localhost"|"127.0.0.1")
		REMOTE=
		;;
	"::1"|"[::1]")
		SPICE="ipv6=on,ipv4=off,disable-ticketing=on"
		REMOTE=
		;;
	"["*"]")
		# External IPv6 address
		[ -n "$HOST" ] && [ -n "$PORT" ] ||
			REMOTE=
		SPICE="ipv6=on,ipv4=off,disable-ticketing=on"
		;;
	*)	# External IPv4 address or hostname
		[ -n "$HOST" ] && [ -n "$PORT" ] ||
			REMOTE=
		;;
	esac

	# Top
	cat <<-EOF
	#!/bin/sh -efu

	export QEMU_AUDIO_DRV="\${QEMU_AUDIO_DRV:-none}"

	exec "qemu-system-$QEMUARCH" -name "$GUESTNAME" \\
	  -nodefaults -no-user-config -seed "$RANDOM" -device virtio-rng \\
	EOF

	# Machine type, CPU and memory
	if [ -z "$UEFI" ]; then
		cat <<-EOF
		  -machine type=pc,accel=kvm -enable-kvm -cpu "$cpu" \\
		  -smp sockets="$SOCKETS",cores="$CORES" -m "$MEMORY" \\
		EOF
	else
		cat <<-EOF
		  -machine type=q35,accel=kvm -enable-kvm -smbios type=0,uefi=on \\
		  -cpu "$cpu" -smp sockets="$SOCKETS",cores="$CORES" -m "$MEMORY" \\
		  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \\
		  -drive if=pflash,format=raw,file="efivars.bin" \\
		EOF
	fi
}

vm_build_disks() {
	local i=0 fmt="" fname="" img type
	local list=( "${IMAGES[@]}" "${ARG_IMAGES[@]}" )

	# Storage buses
	for img in "${list[@]}"; do
		type="${img%%=*}"
		[ "$type" != AHCI ] ||
			fmt=1
		[ "$type" != SCSI ] ||
			fname=1
	done
	if [ -n "$fmt" ]; then
		cat <<-EOF
		  -device ahci,id=ahci \\
		EOF
	fi
	if [ -n "$fname" ]; then
		cat <<-EOF
		  -device virtio-scsi-pci,id=scsi0,num_queues="$CORES" \\
		EOF
	fi

	# Disk drive(s) list in one of these forms:
	# 'AHCI=raw=disk-0.img' or 'SCSI=disk-1.img'
	for img in "${list[@]}"; do
		type="${img%%=*}"
		[ "$type" != "$img" ] ||
			fatal "Invalid disk image specification: '$img'."
		fname="${img#"$type"=*}"
		fmt="${fname%%=*}"
		[ "$fmt" = "$fname" ] && fmt=qcow2 ||
			fname="${fname#"$fmt"=*}"

		case "$type" in
		AHCI)
			cat <<-EOF
			  -drive if=none,id=drive$i,format="$fmt",file="$fname" \\
			  -device ide-hd,drive=drive$i,bus=ahci.$i \\
			EOF
			;;
		NVME)
			cat <<-EOF
			  -drive if=none,id=nvme$i,format="$fmt",file="$fname" \\
			  -device nvme,drive=nvme$i,serial=deadbeaf1,num_queues="$CORES" \\
			EOF
			;;
		SCSI)
			cat <<-EOF
			  -drive if=none,id=drive$i,format="$fmt",file="$fname" \\
			  -device scsi-hd,drive=drive$i,bus=scsi0.$i,channel=0,scsi-id=$i,lun=0 \\
			EOF
			;;
		VIRT)
			cat <<-EOF
			  -drive if=none,id=drive$i,discard=ignore,aio=threads,format="$fmt",file="$fname" \\
			  -device virtio-blk-pci,drive=drive$i,scsi=off,write-cache=off \\
			EOF
			;;
		*)
			fatal "Unsupported disk interface type: '$type'."
			;;
		esac

		[ -s "$fname" ] ||
			fatal "Disk image not found: '$fname'."
		i="$((1 + $i))"
	done
}

vm_build_network() {
	local i=0 xRW tag share hdir
	local ro="local,security_model=passthrough,readonly=on"
	local rw="local,security_model=none"

	# First network adapter is required
	cat <<-EOF
	  -netdev user,id=net0,restrict=no${FORWARDS:+,$FORWARDS} \\
	  -device virtio-net-pci,netdev=net0,id=eth0 \\
	EOF

	# Shared folders between host and guest
	for share in "${SHARES[@]}"; do
		tag="${share%%:*}"
		[ "$tag" != "$share" ] ||
			fatal "Invalid share folder specification: '$share'."
		hdir="${share#"$tag":*}"
		xRW="$ro"

		case "$hdir" in
		"rw:"*)	xRW="$rw"
			hdir="${hdir:3}"
			;;
		esac

		case "$hdir" in
		"@MIRROR@"*)
			hdir="${MEDIA}${MEDIA_MIRROR}${hdir##@MIRROR@}"
			;;
		"@DATADIR@"*)
			hdir="${WORKDIR}/.out${hdir##@DATADIR@}"
			;;
		"@INDIR@"*)
			hdir="${WORKDIR}/.in${hdir##@INDIR@}"
			;;
		"@HOSTDIR@"*)
			hdir="${HOSTDIR}${hdir##@HOSTDIR@}"
			;;
		"@MEDIA@"*)
			hdir="${MEDIA}${hdir##@MEDIA@}"
			;;
		esac

		[ -d "$hdir" ] ||
			fatal "Directory not found: '$hdir'."
		cat <<-EOF
		  -fsdev $xRW,id=fsdev$i,path="$hdir" \\
		  -device virtio-9p-pci,id=fs$i,fsdev=fsdev$i,mount_tag="$tag" \\
		EOF
		i="$((1 + $i))"
	done
}

vm_build_video() {
	if [ -n "$PORT" ] && [ -n "$HOST" ]; then
		cat <<-EOF
		  -vga qxl -spice port="$PORT",addr="$HOST",$SPICE \\
		EOF
	fi
	unset SPICE
}

remote_on() {
	REMOTE_PID=

	[ -n "$HOST" ] && [ -n "$PORT" ] ||
		return 0

	if [ -z "$REMOTE" ] && which remote-viewer &>/dev/null; then
		remote-viewer "spice://$HOST:$PORT" &>/dev/null & REMOTE_PID=$!
	else
		printf "At the remote machine you can run: "
		printf "'remote-viewer spice://%s:%s'\n" "$HOST" "$PORT"
	fi
}

remote_off() {
	[ -z "$REMOTE_PID" ] ||
		wait $REMOTE_PID &>/dev/null ||:
	unset REMOTE_PID
}
