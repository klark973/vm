# vm-help.sh -- show the help message and exit.
#
# This file is covered by the GNU General Public License
# version 3, or (at your option) any later version, which
# should be included with sources as the file COPYING.
#
# Copyright (C) 2023, Leonid Krivoshein <klark@altlinux.org>
#
. "$LIBEXEC"/vm-cmd-run.sh

COMMANDS="$(find "$LIBEXEC" -type f -name 'vm-cmd-*.sh' |sort |
while read -r name; do
	name="${name##*/vm-cmd-}";
	name="${name%.sh*}";
	[ "$name" != run ] ||
		continue;
	echo "$name";
done)"

ARGS="$(vm_cmd_run_args |cut -f3- -d:)"

cat <<EOF
Common: $PROG [<options>] [--] [@]<command1> [<arg1>...] [@][...]
Simple: $PROG [<options>] [--] [<ISOIMAGE>]

 Usage: $PROG [<options>] [--] [@]run$ARGS
EOF

for i in $COMMANDS; do
	. "$LIBEXEC/vm-cmd-$i.sh"
	ARGS="$(vm_cmd_${i}_args |cut -f3- -d:)"
	echo "    or: $PROG [<options>] [--] [@]${i}$ARGS"
done

cat <<EOF

Commands:
EOF

for i in run $COMMANDS; do
	"vm_cmd_${i}_help"
done

unset i ARGS COMMANDS

cat <<EOF

Arguments:
  ISOIMAGE        Relative or absolute path to an ISO-image for boot
                  the target VM from.
  JOBNAME         Name of the sub-directory with the data and scripts
                  which will be executed inside special RESCUE VM.
  GUESTNAME       Name of the creating Virtual Machine.
  SNAPSHOT        Name of the creating or used snapshot.
  DESCRIPTION     Brief snapshot description.

Special macros:
  @MEDIA@         Path to the optional external disk drive.
  @MIRROR@        Path to the package repositories mirror.
  @HOSTDIR@       VM host directory ($HOSTDIR).
  @INDIR@         Source data and scripts directory.
  @DATADIR@       Data directory for saving results.

  It may use for substitues real pathes from the OS in '--image=...'
  and '--shares=...' options.

Options:
  -D, --disks=    Specify virtual HDD type(s)+size(s) comma separated
                  list in the form <TYPE>=<SIZE>,.. Here allowed types:
                  'AHCI', 'NVME', 'SCSI' and 'VIRT'. By default, the
                  following disk drive(s) will be created: '$DISKS'.
  -H, --host=     Specify the hostname or IP-address that SPICE will
                  listen on, default is '$HOST'.
  -S, --sockets=  Specify number of the CPU sockets, default is $SOCKETS.
  -a, --arch=     Specify qemu guest VM CPU architecture, default
                  is '$QEMUARCH'.
  -c, --cores=    Specify number of the CPU cores, default is $CORES.
  -d, --hostdir=  Specify Virtal Machine host directory, default
                  is '$HOSTDIR'.
  -f, --forward=  Specify one network forwarding rule, for first network
                  adapter only. This option can be specified multiple
                  times. Default is '$FORWARDS'.
  -i, --image=    Specify path to an additional image file in the form
                  <TYPE>=[<FMT>=]<PATH>. Here is possible to specify
                  formats: 'qcow2' (used by default), 'raw', etc...,
                  which supported by qemu. This option can be specified
                  multiple times.
  -k, --keep-cd   Don't eject CD-ROM and continue using it after first
                  time OS setup.
  -m, --memory=   Specify memory size, default is '$MEMORY'.
  -n, --no-colors Switch OFF colorized output to the console.
  -p, --port=     Specify port number that SPICE will listen on. Empty
                  value turn OFF using SPICE protocol. Default is $PORT.
  -r, --rescue=   Specify alternative RESCUE VM profile name, default
                  is '$RESCUE'.
  -s, --share=    Create an additional share folder between host and
                  guest in the form <ID>:[rw:]<HOSTDIR>. This option
                  can be specified multiple times.
  -t, --timeout=  Specify job execution timeout. By default, it is
                  ${TIMEOUT:-unlimited}.
  -u, --uefi      First time OS setup in UEFI boot mode.
  --no-keep-cd    Eject ISO-image from the tray after OS setup.
  --no-uefi       Don't use UEFI boot mode at the first time OS setup.
  --use-tmpdir    Use separate working directory for temporary files.
  --inplace,
  --no-tmpdir     Do everything in the host directory, don't use
                  separate working directory for temporary files.
  -v, --version   Show this program version and exit.
  -h, --help      Show this help message and exit.

Example:
  $PROG -c 8 -m 4G @create WS10 /iso/image.iso @job prepare @run @backup

  VM files will be created in the current directory with the following
  parameters: GUESTNAME=WS10, CORES=8, MEMORY=4G, BOOTIMAGE=/iso/image.iso,
  all other by default; then job 'prepare' will be executed inside special
  RESCUE VM; then VM will be bootted once from the specified BOOTIMAGE;
  and after the VM will be shutdowned, the snapshot "S0" will be created.
EOF

exit 0
