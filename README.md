# VM

VM is a simple set of scripts for myself that can be used to automate
the startup and deployment of virtual machines. It is just a wrapper
over the qemu command line.

## Requires

- `qemu-system-*` binary for your platform.
- `qemu-img` binary for creating initial HDD's.
- `pigz` and `unpigz` binaries for snapshoting.
- `remote-viewer` binary (optional) for working with guest VM.
- `bash` on host and `sh` inside Rescue VM for executing jobs.

## Features

- Creating, saving, restoring and destroying VM's.
- Many useful defaults for your VM's already set.
- Execution jobs-scripts inside ALT Rescue VM.
- Using color console and ability to tune colors.
- Optional using external media for store big data.
- Running on local computer with the graphics card.
- Running on remote server. SPICE can use in any case.
- Creating working files in place and in the `$TMPDIR` (default).

## Preparing working space

- Copy scripts from `bin` to your binary directory and make it executable.
  You can modify this scripts as needed.
- Create sub-directory `vm` in your home directory and copy `scripts`
  sub-directory to.
- Prepare special rescue ISO-image for execution jobs inside ALT Rescue.
- Copy following lines to your `~/.ssh/config`:

```
Host    kvm
        Hostname 127.0.0.1
        NoHostAuthenticationForLocalhost yes
        IdentityFile ~/.ssh/id_ed25519
        Port 5555
        User root
```

## Preparing special rescue ISO-image

```bash
$ mkdir -p -m 755 ~/tmp/stage3
$ cp -Lf ~/vm/scripts/rescue-stage3 ~/tmp/stage3/autorun
$ alt2deploy -r ~/tmp/stage3 alt-p10-rescue-latest-x86_64.iso rescue-p10-x86_64.iso
$ rm -rf ~/tmp/stage3
```

## Changing the defaults

- `/etc/vm.conf` - global settings for all users, they override the defaults.
- `~/.config/vm.conf` - user personal setting, they also override the global
  settings for all users.
- `vm.defaults` - additional qemu arguments: this file can be placed in
  the `/etc`, `~/.config`, `$HOSTDIR` or `$WORKDIR` directories (see
  `vm-cmd-run.sh` to get more details.

## Creating snapshots

You can take as many snapshots as needed. The snapshot can be given an
arbitrary name. You can add a short description to the snapshot. By default,
snapshots are automatically named as `S0`, `S1`, `S2`, etc... The symlink
`LAST` points to the last snapshot taken.

## Restoring from a snapshot

The `vm restore` command allows you to restore the working state of
the VM from the last snapshot taken. To restore from another snapshot,
you should specify its name, ex.: `vm restore 2023-05-10`. If no working
files are found when the VM starts up, a restore from the latest snapshot
is automatically started.

## Jobs

A job is an arbitrary set of files, one, two or three scripts, of which
only script `.job` is required. Job scripts can be located in two places:
in the VM directory and in the general location for storing them:
`$LIBEXEC/jobs`. The rest of the files for a guest can be anywhere.

Usually script `.pre` copies everything needed to `$WORKDIR/.in/`, script
`.job` is copied there too. After the job has completed and the virtual
machine has shut down, the script `.post` will be run, if available.

Inside rescue VM you can use following mounted directories:

- `/tmp/.mirror` (optional, read only) - repositories mirror.
- `/tmp/.in` (read only) - for reading input data for the job.
- `/tmp/.out` (full access) - for saving job results and logs.

Inside `<JOBNAME>.pre` and `<JOBNAME>.post` scripts you can use
all variables which declared in `vm-main.sh`. Most useful are:

- `$HOSTDIR` - primary directory with VM snapshots and settings.
- `$WORKDIR` - temporary directory with working files of the VM.
  It may be same as `$HOSTDIR` only when program running with the
  option `--inplace`, but by default working files created on the
  runfs or tmpfs.
- `$LIBEXEC` - directory with this utility scripts such as `vm-main.sh`.

Script `<JOBNAME>.job` running inside special rescue VM. It can use
following variables:

- `$MIRROR` - repositories mirror (optional, read only).
- `$INDIR` - path to input data from the host system (read only).
- `$OUTDIR` - directory for saving results and logs (full access).
- `$MNTOPTS` - 9p-shares mount options for data exchange between
  host and guest systems.

### add-ssh-keys job

This job copies all existing public SSH-keys, as specified by the `$SSHKEYS`
variable, to the guest VM and adds each SSH-key for the superuser inside the
installed guest OS. After completing this job you can login to the guest VM
without a password prompt as superuser.

### run-ssh job

This job also adds SSH-keys, but not to the installed system, but to a
specialized rescue system, after which it raises the network in this rescue
system, generates host keys and starts the SSH service. This allows further
jobs to be executed via ssh immediately, no need to wait for the VM to start.
To shut down a VM in a SSH-session, just remove the `$WORKDIR/.out/RELEASE`
file and disconnect.

## Usage examples

`vm -c 8 -m 4G @create WS10 /iso/image.iso @job prepare @run @backup`

VM files will be created in the current directory with the following
parameters: GUESTNAME=WS10, CORES=8, MEMORY=4G, BOOTIMAGE=/iso/image.iso,
all other by default; then job 'prepare' will be executed inside special
RESCUE VM; then VM will be bootted once from the specified BOOTIMAGE;
and after the VM will be switched off, a snapshot "S0" will be created.

`vm --no-uefi --tmeout=30 @restore S2 @job add-ssh-keys`

VM will be restored from snapshot S2; then job 'add-ssh-keys' will be
executed inside special RESCUE VM: this job has a 30 seconds time limit
for executing from job start, and VM will be started in Legacy/CSM mode,
even if it VM was created with UEFI-boot.

![More VM examples](vm.png "Typical usage of the VM utility")

## Getting help

Just run: `vm -h`.

## License

VM is licensed under the GNU General Public License (GPL), version 3,
or (at your option) any later version.
