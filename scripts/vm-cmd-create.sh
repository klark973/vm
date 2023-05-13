# vm-cmd-create.sh -- create new Virtal Machine.
#
# This file is covered by the GNU General Public License
# version 3, or (at your option) any later version, which
# should be included with sources as the file COPYING.
#
# Copyright (C) 2023, Leonid Krivoshein <klark@altlinux.org>
#
if [ -z "${vm_cmd_create_included-}" ]; then
vm_cmd_create_included=1

vm_cmd_create_args() {
	echo "1:2: <GUESTNAME> [<ISOIMAGE>]"
}

vm_cmd_create_help() {
	echo "  [@]create       Create new VM with the specified parameters."
}

vm_cmd_create_exec() {
	local guestname="${1-}"
	local i disk="${2-}"

	# Pre-requires
	[ -n "$guestname" ] ||
		fatal "Argument: <GUESTNAME> cannot be empty."
	[ ! -s "$HOSTDIR/guest.env" ] ||
		fatal "Environment file already created, delete it first."
	if [ -n "$INPLACE" ]; then
		i="$(find "$HOSTDIR" -maxdepth 1 -type f -name 'disk-*.img' \
			2>/dev/null |wc -l)"
		[ "$i" = 0 ] ||
			fatal "VM image file(s) already exists, delete it first."
	fi
	if [ -d "$HOSTDIR/backups" ]; then
		i="$(find "$HOSTDIR/backups" -type f -name 'disk-*.img.gz' \
			2>/dev/null |wc -l)"
		[ "$i" = 0 ] ||
			fatal "Snapshot(s) already exists, delete it first."
	fi

	# Check few executables
	check_requires

	# Configuration
	[ -z "$disk" ] ||
		ISO="$disk"
	[ -n "$ISO" ] ||
		KEEPCD=
	[ -z "$ARG_ARCH" ] ||
		QEMUARCH="$ARG_ARCH"
	if [ "$ARG_UEFI" = 1 ]; then
		UEFI=1
	elif [ "$ARG_UEFI" = 0 ]; then
		UEFI=
	fi

	# Check OVMF firmware
	if [ -n "$UEFI" ]; then
		[ -s "$OVMF_CODE" ] && [ -s "$OVMF_VARS" ] ||
			fatal "OVMF firmware package is not installed."
	fi

	# Create working directory
	if [ -z "$INPLACE" ]; then
		create_workdir

		# Additional check to an existings disk images
		i="$(find "$WORKDIR" -maxdepth 1 -type f -name 'disk-*.img' \
			2>/dev/null |wc -l)"
		[ "$i" = 0 ] ||
			fatal "VM image file(s) already exists, delete it first."
	fi

	# Create NVRAM
	[ -z "$UEFI" ] ||
		cp -Lf -- "$OVMF_VARS" "$WORKDIR"/efivars.bin
	i=0

	# Create virtual disk images
	for disk in ${DISKS//,/ }; do
		qemu-img create -o size="${disk##*=}" -f qcow2 -- "$WORKDIR/disk-$i.img"
		IMAGES=( "${IMAGES[@]}" "${disk%=*}=disk-$i.img" )
		i="$((1 + $i))"
	done

	# Save VM settings
	( cat <<-EOF
		# Auto-generated VM environment.
		# NEVER EDIT THIS FILE MANUALLY!
		#
		GUESTNAME="$guestname"
		QEMUARCH="$QEMUARCH"
		SOCKETS=$SOCKETS
		CORES=$CORES
		MEMORY="$MEMORY"
		UEFI=$UEFI
		ISO="$ISO"
		KEEPCD=$KEEPCD
		FORWARDS="$FORWARDS"
		HOST="$HOST"
		PORT="$PORT"
		SHARES=(
		EOF
	  #
	  for i in "${SHARES[@]}"; do
		printf "	\"%s\"\n" "$i"
	  done
	  #
	  printf ")\n"
	  #
	  if [ "${#IMAGES[@]}" != 0 ]; then
		printf "IMAGES=(\n"
		#
		for disk in "${IMAGES[@]}"; do
			printf "	\"%s\"\n" "$disk"
		done
		#
		printf ")\n"
	  fi
	) >"$WORKDIR"/guest.env
	#
	IMAGES=()
	( . "$WORKDIR"/guest.env ) >/dev/null 2>&1 ||
		fatal "Invalid parameters set."
	:> "$WORKDIR"/FIRSTTIME
	printf "${CLR_OK}*** VM was created successfully!${CLR_NORM}\n"
}

fi # vm_cmd_create_included
