# vm-cmd-restore.sh -- restore Virtal Machine from snapshot.
#
# This file is covered by the GNU General Public License
# version 3, or (at your option) any later version, which
# should be included with sources as the file COPYING.
#
# Copyright (C) 2023, Leonid Krivoshein <klark@altlinux.org>
#
if [ -z "${vm_cmd_restore_included-}" ]; then
vm_cmd_restore_included=1

vm_cmd_restore_args() {
	echo "0:1: [<SNAPSHOT>]"
}

vm_cmd_restore_help() {
	echo "  [@]restore      Restore VM from the last or specified snapshot."
}

vm_cmd_restore_exec() {
	local snapname="${1-}"
	local i files currdir="$PWD"

	[ -n "$snapname" ] ||
		snapname="$(vm_cmd_restore_last)"
	[ -n "$snapname" ] ||
		fatal "Snapshot not specified, nothing to restore."
	[ -s "$HOSTDIR/backups/$snapname/guest.env" ] &&
	[ -s "$HOSTDIR/backups/$snapname/disk-0.img.gz" ] ||
		fatal "Invalid snapshot: '$snapname'."
	which unpigz >/dev/null 2>&1 ||
		fatal "Programm 'unpigz' is not installed."
	printf "${CLR_LC1}*** Restoring from snapshot "
	printf "'${CLR_LC2}%s${CLR_LC1}'...${CLR_NORM}\n" "$snapname"

	cd -- "$HOSTDIR/backups/$snapname"/
	files="$(find . -maxdepth 1 -type f -name 'disk-*.img.gz' |
			cut -c3- |
			sort)"
	[ ! -s efivars.bin.gz ] ||
		files="$files efivars.bin.gz"
	create_workdir

	for i in $files; do
		i="${i%*.gz}"
		printf "  - restoring '%s'..." "$i"
		if unpigz -qnc < "$i.gz" > "$WORKDIR/$i"; then
			printf " ${CLR_OK}done${CLR_NORM}\n"
		else
			printf " ${CLR_ERR}fail (%s)${CLR_NORM}\n" "$?"
			cd -- "$currdir"/ 2>/dev/null ||:
			fatal "Snapshot '$snapname' was not restored!"
		fi
	done

	[ ! -f "$PROG.defaults" ] ||
		cp -Lf -- "$PROG.defaults" "$WORKDIR"/
	cp -Lf -- guest.env "$WORKDIR"/
	i="$(du -sh . |cut -f1)"
	printf "${CLR_OK}*** Snapshot '${CLR_LC2}%s${CLR_OK}' " "$snapname"
	printf "(%s) was restored successfully!${CLR_NORM}\n" "$i"
	cd -- "$currdir"/ 2>/dev/null ||:
}

vm_cmd_restore_last() {
	local name=

	[ ! -L "$HOSTDIR/backups/LAST" ] ||
		name="$(readlink -fv -- "$HOSTDIR"/backups/LAST)"
	[ -z "$name" ] || [ ! -s "$HOSTDIR/backups/${name##*/}/guest.env" ] ||
		printf "%s" "${name##*/}"
}

fi # vm_cmd_restore_included
