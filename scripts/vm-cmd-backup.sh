# vm-cmd-backup.sh -- create VM current state snapshot.
#
# This file is covered by the GNU General Public License
# version 3, or (at your option) any later version, which
# should be included with sources as the file COPYING.
#
# Copyright (C) 2023, Leonid Krivoshein <klark@altlinux.org>
#
if [ -z "${vm_cmd_backup_included-}" ]; then
vm_cmd_backup_included=1

vm_cmd_backup_args() {
	echo "0:2: [<SNAPSHOT> [<DESCRIPTION>]]"
}

vm_cmd_backup_help() {
	echo "  [@]backup       Create snapshot of the VM current state."
}

vm_cmd_backup_exec() {
	local snapname="${1-}"
	local description="${2-}"
	local i files currdir="$PWD"

	[ -n "$WORKDIR" ] ||
		fatal "The working directory cannot be empty."
	[ -s "$WORKDIR/guest.env" ] && [ -s "$WORKDIR/disk-0.img" ] ||
		fatal "No data to backup."
	[ -n "$snapname" ] ||
		snapname="$(vm_cmd_backup_next)"
	[ ! -d "$HOSTDIR/backups/$snapname" ] ||
		fatal "Snapshot already exists: '$snapname'."
	which pigz >/dev/null 2>&1 ||
		fatal "Programm 'pigz' is not installed."
	printf "${CLR_LC1}*** Creating snapshot "
	printf "'${CLR_LC2}%s${CLR_LC1}'...${CLR_NORM}\n" "$snapname"

	cd -- "$WORKDIR"/
	files="$(find . -maxdepth 1 -type f -name 'disk-*.img' |
			cut -c3- |
			sort)"
	mkdir -p -m 0755 -- "$HOSTDIR/backups/$snapname"
	cd -- "$HOSTDIR/backups/$snapname"/
	[ -z "$description" ] ||
		printf "%s\n" "$description" >DESCRIPTION
	[ ! -s "$WORKDIR/efivars.bin" ] ||
		files="$files efivars.bin"
	[ ! -f "$WORKDIR/$PROG.defaults" ] ||
		cp -Lf -- "$WORKDIR/$PROG.defaults" ./
	cp -Lf -- "$WORKDIR"/guest.env ./

	for i in $files; do
		printf "  - saving '%s'..." "$i"
		if pigz -9qnc < "$WORKDIR/$i" > "$i.gz"; then
			printf " ${CLR_OK}done${CLR_NORM}\n"
		else
			printf " ${CLR_ERR}fail (%s)${CLR_NORM}\n" "$?"
			cd -- "$currdir"/ 2>/dev/null ||:
			rm -rf --one-file-system -- "$HOSTDIR/backups/$snapname"
			fatal "Snapshot '$snapname' was not created!"
		fi
	done

	[ -s "$HOSTDIR/guest.env" ] ||
		cp -Lf -- "$WORKDIR"/guest.env "$HOSTDIR"/
	[ -f "$HOSTDIR/$PROG.defaults" ] || [ ! -f "$WORKDIR/$PROG.defaults" ] ||
		cp -Lf -- "$WORKDIR/$PROG.defaults" "$HOSTDIR"/
	printf "%s\n" "$(LC_TIME=C date "+%F %T")" >TS
	cd -- "$HOSTDIR"/backups/
	ln -snf -- "$snapname" LAST
	i="$(du -sh -- "$snapname" |cut -f1)"
	printf "${CLR_OK}*** Snapshot '${CLR_LC2}%s${CLR_OK}' " "$snapname"
	printf "(%s) was created successfully!${CLR_NORM}\n" "$i"
	cd -- "$currdir"/ 2>/dev/null ||:
}

vm_cmd_backup_next() {
	local n=0

	if [ ! -d "$HOSTDIR/backups/S0" ]; then
		printf "S0"
		return
	fi

	cd -- "$HOSTDIR"/backups/
	n="$(find . -maxdepth 1 -type d -name 'S[0-9]' -or -name 'S[1-9][0-9]' |
		cut -c4- |
		sort -n |
		tail -n1)"
	cd -- "$OLDPWD"/
	printf "%s" "S$((1 + $n))"
}

fi # vm_cmd_backup_included
