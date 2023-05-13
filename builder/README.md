# How to create an ALT builder from JeOS with post-install

Attention: in real life this is not necessary since you can use ready-made
builder ISO-image. These files are provided for demonstration purposes only.

See also: https://www.altlinux.org/Starterkits/builder (Russian only).

## Preparing user profile

Create a VM directory and change into it:

$ `mkdir -p ~/vm/builder && cd ~/vm/builder/`

Copy the "UserProfile" sub-directory and all files "post-install.*" from the
project directory to the `~/vm/builder` directory. Add your public SSH-key
to the user profile and modify other files in the user profile as follows:

```bash
$ find UserProfile -type f -name .placeholder -delete
$ find UserProfile -type f -print0 |xargs -0 sed -i "s/MYUSERNAME/$USERNAME/g"
$ cat ~/.ssh/id_ed25519.pub >> UserProfile/.ssh/authorized_keys
$ ln -snf /tmp/.private/$USERNAME/hasher UserProfile/hasher
$ ln -snf /tmp/.private/$USERNAME UserProfile/tmp
$ mv -f UserProfile $USERNAME
```

If necessary, add your GPG-key as well.

Now create an archive with this user profile:

$ `tar -cpzSf post-install.user-$USERNAME.tgz $USERNAME`

Modify your `~/.ssh/config` like this:

```bash
$ cat >> ~/.ssh/config <<EOF

Host    nevada
        Hostname 127.0.0.1
        NoHostAuthenticationForLocalhost yes
        IdentityFile ~/.ssh/id_ed25519
        Port 5555
        User $USERNAME
EOF
```

This will allow to login into the guest OS with the command `ssh nevada`
as regular user without password prompt.

Now create shared directories between host and guest machines:

$ `mkdir -p -m 755 $HOME/build $HOME/hasher`

## Preparing VM profile

Download the latest JeOS ISO-image from
http://nightly.altlinux.org/sisyphus/snapshots/

$ `wget http://nightly.altlinux.org/sisyphus/snapshots/20230510/regular-jeos-systemd-20230510-x86_64.iso`

and create a symlink "jeos.iso" on it:

$ `ln -snf regular-jeos-systemd-20230510-x86_64.iso jeos.iso`

If `$TMPDIR` is not set on your Linux system or if it points to a drive,
run the following commands. It is necessary to choose the size of runfs
or tmpfs so that on `$TMPDIR` at least 3 Gb is free:

```bash
$ export TMPDIR=/run/user/$UID
$ sudo mount -o remount,size=10% $TMPDIR

$ df -h $TMPDIR
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           3.2G  116K  3.2G   1% /run/user/500
```

Now let's see how many cores your host system has. We will give them all
to the guest OS (by `vm -c 16`).

```bash
$ grep -cw processor /proc/cpuinfo
16
```

Let's also look at the amount of available memory. We will give all free
memory to the guest OS. So, on a laptop with 32 Gb of RAM, I have about
25 Gb available, but 3 Gb is reserved for the virtual disk. So for the
guest OS in this case you can leave 20-22 Gb (by `vm -m 20G`).

```bash
$ free -m
               total        used        free      shared  buff/cache   available
Mem:           31820        1416       24916         605        5487       29352
Swap:          49151           0       49151
```

## Creating the ALT builder VM

So, everything is ready to deploy the OS. Let's do that! Please note
that during the installation we will only use one partition `/dev/vda1`:

```bash
$ vm -c 16 -m 20G -D VIRT=3G @create BUILDER jeos.iso \
  @run @job post-install @backup @run @destroy
*** Executing command: create('BUILDER', 'jeos.iso')...
Formatting '/run/user/500/vm-cSXwYKSl.tmp/disk-0.img', fmt=qcow2
cluster_size=65536 extended_l2=off compression_type=zlib size=3221225472
lazy_refcounts=off refcount_bits=16
*** VM was created successfully!
*** Executing command: run()...
*** Creating guest VM script...
*** Running guest VM...
*** Guest VM is switched off at the moment.
1.4G
*** Executing command: job('post-install')...
* Copying source files and scripts...
*** Waiting to start job script...
*** JOB was started, log connected...

... (post-install log skipped) ...

*** Rescue VM is switched off at the moment.
1.7G
*** Executing command: backup()...
*** Creating snapshot 'S0'...
  - saving 'disk-0.img'... done
*** Snapshot 'S0' (478M) was created successfully!
*** Executing command: run()...
*** Creating guest VM script...
*** Running guest VM...
*** Guest VM is switched off at the moment.
1.7G
*** Executing command: destroy()...
*** VM temporary files was removed!
```

## Using the ALT Builder VM

So, now you can login to the guest OS (`ssh nevada`) and try to
build something:

```bash
# Build an ISO-image
$ make -C /usr/share/mkimage-profiles syslinux.iso

# Build a package
$ cd ~/build/
$ git clone git://git.altlinux.org/gears/h/hello.git
$ cd hello && gear-hsh -- --apt-config=$HOME/.hasher/p10-x86_64.conf
$ hsh --clean
```

You can find the results in the `$HOME/hasher` directory on your host system.

For shut down guest OS, run `su-`, enter the root password and execute the
command `poweroff` or `init 0`.

Enjoy! ;-)
