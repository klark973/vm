# vm-cmd-run.sh -- start an existing Virtual Machine.
#
# This file is covered by the GNU General Public License
# version 3, or (at your option) any later version, which
# should be included with sources as the file COPYING.
#
# Copyright (C) 2023, Leonid Krivoshein <klark@altlinux.org>
#
if [ -z "${vm_cmd_run_included-}" ]; then
vm_cmd_run_included=1

vm_cmd_run_args() {
	echo "0:1: [<ISOIMAGE>]"
}

vm_cmd_run_help() {
	echo "  [@]run          Start an existing VM, it is by default."
}

vm_cmd_run_exec() {
	local i=0 disk="${1-}"

	# Pre-requires
	[ -n "$WORKDIR" ] ||
		exec_cmd_silently restore
	IMAGES=()

	if [ -s "$WORKDIR/guest.env" ]; then
		. "$WORKDIR"/guest.env
	elif [ -s "$HOSTDIR/guest.env" ]; then
		. "$HOSTDIR"/guest.env
	else
		fatal "Environment file not found."
	fi

	if [ "$ARG_UEFI" = 0 ]; then
		UEFI=
	elif [ "$ARG_UEFI" = 1 ]; then
		[ -s "$OVMF_CODE" ] && [ -s "$OVMF_VARS" ] ||
			fatal "OVMF firmware package is not installed."
		[ -s "$WORKDIR/efivars.bin" ] ||
			cp -Lf -- "$OVMF_VARS" "$WORKDIR"/efivars.bin
		UEFI=1
	fi
	if [ -n "$UEFI" ]; then
		[ -s "$OVMF_CODE" ] ||
			fatal "OVMF firmware package is not installed."
		[ -s "$WORKDIR/efivars.bin" ] ||
			fatal "NVRAM file not found."
	fi

	# Check few executables
	check_requires

	# Configuration
	[ -z "$disk" ] ||
		ISO="$disk"
	[ -n "$ISO" ] ||
		KEEPCD=
	REMOTE=1
	CDROM=

	# Check an external media connection
	check_external_media

	# Locate an ISO-image
	[ -z "$ISO" ] ||
		locate_cdrom "$HOSTDIR" "Specified"

	# Run guset VM
	vm_cmd_run_vm

	# Cleanup
	IMAGES=()
	unset CDROM REMOTE
	rm -f -- "$WORKDIR"/FIRSTTIME
}

vm_cmd_run_vm() {
	cd -- "$WORKDIR"/
	printf "${CLR_LC1}*** Creating guest VM script...${CLR_NORM}\n"
	vm_cmd_run_build_vm >run-vm.sh
	printf "${CLR_LC1}*** Running guest VM...${CLR_NORM}\n"
	( sh -efun ./run-vm.sh ) >/dev/null 2>&1 ||
		fatal "Interal error: m.b. invalid arguments? Check run-vm.sh."
	remote_on
	sh -efu ./run-vm.sh ||
		fatal "Guest VM execution failed with status: $?."
	printf "${CLR_OK}*** Guest VM is switched off at the moment.${CLR_NORM}\n"
	remote_off
	du -sh . |cut -f1
	cd -- "$OLDPWD"
}

vm_cmd_run_build_vm() {
	local boot= vmargsfile=

	vm_build_top
	vm_build_disks
	vm_build_network
	vm_build_video

	# Locate an additional arguments
	if [ -z "$INPLACE" ] && [ -f "$WORKDIR/$PROG.defaults" ]; then
		vmargsfile="$WORKDIR/$PROG.defaults"
	elif [ -f "$HOSTDIR/$PROG.defaults" ]; then
		vmargsfile="$HOSTDIR/$PROG.defaults"
	elif [ -f "$HOME/.config/$PROG.defaults" ]; then
		vmargsfile="$HOME/.config/$PROG.defaults"
	elif [ -s "/etc/$PROG.defaults" ]; then
		vmargsfile="/etc/$PROG.defaults"
	fi

	# Bottom
	cat <<-EOF
	  -usb -device qemu-xhci -device usb-ehci -device usb-tablet \\
	EOF
	[ ! -f FIRSTTIME ] ||
		boot="-no-reboot"
	[ -z "$CDROM" ] || [ -z "$boot" ] || [ -n "$UEFI" ] ||
		boot="$boot -boot once=d"
	[ -z "$UEFI" ] ||
		boot="$boot -boot menu=on"
	[ -z "$vmargsfile" ] ||
		grep -vE '^(#.*|[[:space:]]*)$' <"$vmargsfile" |
			sed -E 's/[[:space:]]*\\?$/ \\/g'
	[ -z "$CDROM" ] || [ -z "$KEEPCD" ] && [ -z "$boot" ] ||
		cat <<-EOF
		  -cdrom "$CDROM" \\
		EOF
	printf "  -no-fd-bootchk %s\n" "$boot"
}

fi # vm_cmd_run_included
