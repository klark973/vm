# VM

VM is a simple set of scripts for myself that can be used to automate
the startup and deployment of virtual machines. It is just a wrapper
over the qemu command line.

## Requires

- `qemu-system` binary for your platform.
- `qemu-img` binary for creating initial HDD's.
- `pigz` and `unpigz` binaries for snapshoting.
- `remote-viewer` binary (optional) for working with VM.
- `bash` inside host and `sh` inside Rescue VM for executing jobs.

## Features

- Creating, saving, restoring and destroying VM's.
- Many useful defaults for your VM's already set.
- Execution jobs-scripts inside ALT Rescue VM.
- Using color console and ability to tune colors.
- Optional using external media for store big data.
- Running on local computer with the graphics card.
- Running on remote server. SPICE can use in this case.

## Preparing working space

- Copy scripts from `bin` to your binary directory and make their executable.
  You can modify their as needded.
- Create directory `vm` in your home direcory and copy `scripts` directory to.
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

## Jobs

A job is an arbitrary set of files, one, two or three scripts, of which
only script `.job` is required. Job scripts can be located in two places:
in the VM directory and in the general location for storing them:
`$LIBEXEC/jobs`. The rest of the files can be anywhere.

Usually script `.pre` copies everything needed to `$WORKDIR/.in/`, script
`.job` is copied there too. After the job has completed and the virtual
machine has shut down, the script `.post` will be run, if available.

Inside rescue VM can use following mounted directories:

- `/tmp/.mirror` (optional, read only) - repositories mirror.
- `/tmp/.in` (read only) - for reading input data for the job.
- `/tmp/.out` (full access) - for saving job results and logs.

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
