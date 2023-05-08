#!/bin/sh -efu
# rescue-stage3.sh -- autorun script for stage3 CD-booting.
#
# This file is covered by the GNU General Public License
# version 3, or (at your option) any later version, which
# should be included with sources as the file COPYING.
#
# Copyright (C) 2023, Leonid Krivoshein <klark@altlinux.org>
#
if [ "${0##*/}" = autorun ]; then
	mountpoint /tmp >/dev/null &&
		mount -o remount,exec /tmp ||:
	cp -Lpf -- "$0" /tmp/autorun-moved
	cd / && exec /tmp/autorun-moved "$@"
	exit 1
fi

INDIR=/tmp/.in
OUTDIR=/tmp/.out
MIRROR=/tmp/.mirror
MNTOPTS=trans=virtio,version=9p2000.L,msize=104857600,cache=none


cleanup() {
	local rv=$?

	set +x
	trap - EXIT; cd /
	[ -z "$MIRROR" ] ||
		umount -fl -- "$MIRROR" ||:
	printf "%s\n" "$rv" >"$OUTDIR"/STATUS
	date '+%F %T' >"$OUTDIR"/FINISHED
	umount -fl -- "$OUTDIR" ||:
	umount -fl -- "$INDIR" ||:
	poweroff -f -d

	exit $rv
}

fatal() {
	printf "fatal: %s\n" "$*" >&2
	exit 1
}

run() {
	printf "exec: %s\n" "$*" >&2
	"$@"
}

job() {
	. ./job.sh
}


trap 'poweroff -f -d' EXIT
umount -fl /mnt/autorun 2>/dev/null ||:
mkdir -p -m 0755 -- "$MIRROR" "$INDIR" "$OUTDIR"
if ! mount -t 9p -o "ro,$MNTOPTS" -- "mirror" "$MIRROR"; then
	rmdir -- "$MIRROR" ||:
	MIRROR=
fi
mount -t 9p -o "ro,$MNTOPTS" -- "in" "$INDIR"
mount -t 9p -o "rw,$MNTOPTS,access=any" -- "out" "$OUTDIR"
date '+%F %T' >"$OUTDIR"/STARTED
cd -- "$INDIR"/

trap cleanup EXIT
[ ! -f DEBUG ] ||
	set -x
job >"$OUTDIR"/job.log 2>&1
