# vm-cmd-job.sh -- run JOB inside special RESCUE VM.
#
# This file is covered by the GNU General Public License
# version 3, or (at your option) any later version, which
# should be included with sources as the file COPYING.
#
# Copyright (C) 2023, Leonid Krivoshein <klark@altlinux.org>
#
if [ -z "${vm_cmd_job_included-}" ]; then
vm_cmd_job_included=1

vm_cmd_job_args() {
	echo "1:1: <JOBNAME>"
}

vm_cmd_job_help() {
	echo "  [@]job          Start specified JOB inside special RESCUE VM."
}

vm_cmd_job_exec() {
	local jobname="${1-}"
	local jobbase="$HOSTDIR/$jobname"

	[ -n "$jobname" ] ||
		fatal "JOB name cannot be empty."
	[ -s "$jobbase.job" ] ||
		jobbase="$LIBEXEC/jobs/$jobname"
	[ -s "$jobbase.job" ] ||
		fatal "JOB script not found: '$jobname'."
	[ -n "$RESCUE" ] && [ -s "$PROFILES/$RESCUE/guest.env" ] ||
		fatal "Special rescue profile not found: '$RESCUE'."
	[ -n "$WORKDIR" ] ||
		fatal "The working directory cannot be empty."
	IMAGES=()

	rm -rf --one-file-system -- "$WORKDIR"/.in "$WORKDIR"/.out
	mkdir -p -m 0755 -- "$WORKDIR"/.in "$WORKDIR"/.out

	if [ -s "$WORKDIR"/guest.env ]; then
		. "$WORKDIR"/guest.env
	elif [ -s "$HOSTDIR"/guest.env ]; then
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
		[ -s "$WORKDIR"/efivars.bin ] ||
			fatal "NVRAM file not found."
	fi

	# Check few executables
	check_requires

	vm_cmd_job_pre "$jobbase"
	(
	  vm_cmd_job_conf
	  vm_cmd_job_check
	  vm_cmd_job_rescue
	)
	vm_cmd_job_post "$jobbase"

	# Cleanup
	IMAGES=()
}

vm_cmd_job_pre() {
	[ ! -s "$1.pre" ] ||
		( . "$1.pre" )
	cp -Lf -- "$1.job" "$WORKDIR"/.in/job.sh
}

vm_cmd_job_post() {
	[ ! -s "$1.post" ] ||
		( . "$1.post" )
	rm -rf --one-file-system -- "$WORKDIR"/.in
}

vm_cmd_job_conf() {
	RESCUE_ISO=
	RESCUE_SOCKETS=1
	RESCUE_CORES=2
	RESCUE_MEMORY="2G"
	RESCUE_FORWARDS=
	RESCUE_SHARES=(
		"mirror:@MIRROR@"
		"in:@INDIR@"
		"out:rw:@DATADIR@"
	)

	. "$PROFILES/$RESCUE"/guest.env

	[ -n "$RESCUE_ISO" ] ||
		fatal "Path to the ISO-image for rescue VM is required."
	[ -z "$RESCUE_SOCKETS" ] ||
		SOCKETS="$RESCUE_SOCKETS"
	[ -z "$RESCUE_CORES" ] ||
		CORES="$RESCUE_CORES"
	[ -z "$RESCUE_MEMORY" ] ||
		MEMORY="$RESCUE_MEMORY"
	[ -z "$RESCUE_FORWARDS" ] ||
		FORWARDS="$RESCUE_FORWARDS"
	SHARES=( "${RESCUE_SHARES[@]}" )
	ISO="$RESCUE_ISO"
	REMOTE=1
	CDROM=

	unset RESCUE_SHARES
	unset RESCUE_FORWARDS
	unset RESCUE_MEMORY
	unset RESCUE_CORES
	unset RESCUE_SOCKETS
	unset RESCUE_ISO
}

vm_cmd_job_check() {
	check_external_media
	locate_cdrom "$PROFILES/$RESCUE" "Special rescue"
}

vm_cmd_job_rescue() {
	local i=0 vm_pid tail_pid

	cd -- "$WORKDIR"/
	vm_cmd_job_build_vm >run-rescue.sh
	( sh -efun ./run-rescue.sh ) >/dev/null 2>&1 ||
		fatal "Interal error: m.b. invalid arguments? Check run-rescue.sh."
	sh -efu ./run-rescue.sh & vm_pid=$!
	remote_on

	printf "${CLR_LC1}*** Waiting to start job script...${CLR_NORM}\n"
	while [ "$i" -lt 120 ]; do
		[ ! -s "$WORKDIR"/.out/STARTED ] ||
			break
		i=$((1 + $i))
		sleep 1
	done
	if [ ! -s "$WORKDIR"/.out/STARTED ]; then
		kill -KILL $vm_pid &>/dev/null ||:
		wait $vm_pid $REMOTE_PID &>/dev/null ||:
		fatal "Timed out while starting rescue VM."
	fi
	[ -f "$WORKDIR"/.out/job.log ] ||
		sleep .5
	printf "${CLR_LC1}*** JOB was started, log connected...${CLR_NORM}\n\n"
	tail -f -- "$WORKDIR"/.out/job.log & tail_pid=$!

	i=0
	while [ ! -s "$WORKDIR"/.out/STATUS ]; do
		if [ -n "$TIMEOUT" ]; then
			[ "$i" -lt "$TIMEOUT" ] ||
				break
			i=$((1 + $i))
		fi
		sleep 1
	done

	if [ ! -s "$WORKDIR"/.out/STATUS ]; then
		kill -KILL $vm_pid $tail_pid &>/dev/null ||:
		wait $vm_pid $tail_pid $REMOTE_PID &>/dev/null ||:
		fatal "Timed out while executing a job."
	fi
	wait $vm_pid &>/dev/null ||:
	kill -KILL $tail_pid &>/dev/null ||:
	wait $tail_pid $REMOTE_PID &>/dev/null ||:
	[ "$(head -n1 -- "$WORKDIR"/.out/STATUS)" = 0 ] ||
		fatal "Rescue VM execution failed with status: $i."
	printf "\n${CLR_OK}*** Rescue VM is switched off at the moment.${CLR_NORM}\n"
	unset CDROM REMOTE REMOTE_PID
	du -sh . |cut -f1
	cd -- "$OLDPWD"
}

vm_cmd_job_build_vm() {
	local boot

	vm_build_top
	vm_build_disks
	vm_build_network
	vm_build_video

	# Bottom
	[ -z "$UEFI" ] && boot="-boot once=d" ||
		boot="-boot menu=on"
	cat <<-EOF
	  -cdrom "$CDROM" \\
	EOF
	printf "  -no-fd-bootchk %s\n" "$boot"
}

fi # vm_cmd_job_included
