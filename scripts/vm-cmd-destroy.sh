# vm-cmd-destroy.sh -- remove VM temporary files.
#
# This file is covered by the GNU General Public License
# version 3, or (at your option) any later version, which
# should be included with sources as the file COPYING.
#
# Copyright (C) 2023, Leonid Krivoshein <klark@altlinux.org>
#
if [ -z "${vm_cmd_destroy_included-}" ]; then
vm_cmd_destroy_included=1

vm_cmd_destroy_args() {
	echo "0:0:"
}

vm_cmd_destroy_help() {
	echo "  [@]destroy      Remove all temporary files linked with the VM."
}

vm_cmd_destroy_exec() {
	cd -- "$HOSTDIR"/

	if [ "$WORKDIR" = "$HOSTDIR" ]; then
		[ -z "$WORKDIR" ] ||
			rm -rf --one-file-system -- "$WORKDIR"/.in "$WORKDIR"/.out
		find . -maxdepth 1 -type f -name 'disk-*.img' -delete
		rm -f efivars.bin run-vm.sh run-rescue.sh
	else
		[ -z "$WORKDIR" ] ||
			rm -rf --one-file-system -- "$WORKDIR"
		rm -rf --one-file-system -- .work
		WORKDIR=
	fi

	printf "${CLR_OK}*** VM temporary files was removed!${CLR_NORM}\n"
}

fi # vm_cmd_destroy_included
