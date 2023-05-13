#!/bin/sh

# Sanity check
[ -n "$MIRROR" ] ||
	fatal "The MIRROR is required for launch post-install."
export LC_ALL=C

SETUP_TIMEZONE="${SETUP_TIMEZONE:-Europe/Moscow}"
SETUP_USERNAME="${SETUP_USERNAME:-user}"
SETUP_USER_UID="${SETUP_USER_UID:-500}"
SETUP_HOSTNAME="${SETUP_HOSTNAME-}"
SETUP_PASSWORD="${SETUP_PASSWORD-}"
SETUP_ROOT_PWD="${SETUP_ROOT_PWD-}"

printf "\n* STEP 1: Preparing the system for a full upgrade...\n"
run mkdir -p -m 0755 -- "$DESTDIR"/ALT
run mount --bind -- "$MIRROR" "$DESTDIR"/ALT
run sed -i -E 's/^rpm/#rpm/g' "$DESTDIR"/etc/apt/sources.list
(set +f; sed -i -E 's/^rpm/#rpm/g' "$DESTDIR"/etc/apt/sources.list.d/*.list) 2>/dev/null
echo 'LANG="en_US.UTF-8"' > "$DESTDIR"/etc/locale.conf
cat > "$DESTDIR"/etc/apt/sources.list.d/local.list <<EOF
# Local mirror
rpm file:/ALT/Sisyphus x86_64 classic
rpm file:/ALT/Sisyphus noarch classic
EOF
if [ -n "$SETUP_HOSTNAME" ]; then
	run sed -i -E "s/^HOSTNAME=.*/HOSTNAME=$SETUP_HOSTNAME/g" \
				"$DESTDIR"/etc/sysconfig/network
	echo "$SETUP_HOSTNAME" > "$DESTDIR"/etc/hostname
fi

chrooted() {
	run chroot "$DESTDIR" "$@"
}

printf "\n* STEP 2: Upgrading the system and installing additional software...\n"
chrooted apt-get remove --purge -y grub-efi mdadm mdadm-tool nfs-utils
chrooted apt-get update && chrooted apt-get dist-upgrade -y
chrooted apt-get install -y tzdata git-core bash-completion \
			htop mc gear mkimage mkimage-profiles
(set +f; rm -f -- "$DESTDIR"/var/lib/apt/lists/*.* ||:) 2>/dev/null
chrooted apt-get clean

printf "\n* STEP 3: Changing system settings...\n"
chrooted systemctl enable sshd.service
[ ! -x "$DESTDIR"/usr/sbin/hasher-privd ] ||
	chrooted systemctl enable hasher-privd.service ||:
echo "allowed_mountpoints=/proc" >> "$DESTDIR"/etc/hasher-priv/system
echo "ZONE=\"$SETUP_TIMEZONE\"" >> "$DESTDIR"/etc/sysconfig/clock
chrooted ln -snf -- "/usr/share/zoneinfo/$SETUP_TIMEZONE" /etc/localtime
run sed -i -E "s/^#GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/g" "$DESTDIR"/etc/sysconfig/grub2
chrooted update-grub
cat >> "$DESTDIR"/etc/fstab <<EOF
none	/tmp/.private		tmpfs	noatime,nosuid,size=80%	0 0
build	/home/$SETUP_USERNAME/build	9p	rw,$MNTOPTS	0 0
host	/home/$SETUP_USERNAME/out		9p	rw,$MNTOPTS	0 0
mirror	/ALT			9p	ro,$MNTOPTS	0 0
EOF
[ -z "$SETUP_HOSTNAME" ] || [ ! -s "$SETUP_PROFILE.host-$SETUP_HOSTNAME.tgz" ] ||
	run tar -xpSf "$SETUP_PROFILE.host-$SETUP_HOSTNAME.tgz" -C "$DESTDIR" --overwrite
if [ -n "$SETUP_ROOT_PWD" ]; then
	(echo "$SETUP_ROOT_PWD"; echo "$SETUP_ROOT_PWD") |
		chrooted passwd --stdin root >/dev/null
fi

printf "\n* STEP 4: Creating a regular user...\n"
chrooted groupadd -g "$SETUP_USER_UID" -- "$SETUP_USERNAME"
chrooted useradd -u "$SETUP_USER_UID" -g "$SETUP_USER_UID" \
		-N -s /bin/bash -m -d "/home/$SETUP_USERNAME" \
		-G "$SETUP_USERNAME",proc,wheel -- "$SETUP_USERNAME"
run rm -rf -- "$DESTDIR/home/$SETUP_USERNAME/.xsession.d"
run rm -rf -- "$DESTDIR/home/$SETUP_USERNAME/.xprofile"
chrooted hasher-useradd -- "$SETUP_USERNAME"
if [ -s "$SETUP_PROFILE.user-$SETUP_USERNAME.tgz" ]; then
	run tar -xpSf "$SETUP_PROFILE.user-$SETUP_USERNAME.tgz" -C "$DESTDIR"/home --overwrite
	run chown -R "$SETUP_USER_UID:$SETUP_USER_UID" -- "$DESTDIR/home/$SETUP_USERNAME"
fi
if [ -n "$SETUP_PASSWORD" ]; then
	(echo "$SETUP_PASSWORD"; echo "$SETUP_PASSWORD") |
		chrooted passwd --stdin -- "$SETUP_USERNAME" >/dev/null
fi
