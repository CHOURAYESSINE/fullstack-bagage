#!/bin/bash
# Exécuter sur la VM outil uniquement, avec le nouveau disque dédié en /dev/sdb.
# Les secrets sont lus dans le dossier privé /home/yessine/bagage-install.
set -euo pipefail
base=/home/yessine/bagage-install
exec > "$base/install.log" 2>&1
disk=/dev/sdb
target=/mnt/bagage-new-root
iso=/mnt/bagage-source-iso
test "$(blockdev --getsize64 "$disk")" = 21474836480
root_device=$(findmnt -no SOURCE /)
case "$root_device" in /dev/sdb*) echo 'REFUS : le disque cible contient le systeme actif'; exit 1;; esac
if lsblk -nrpo MOUNTPOINT "$disk" | grep -q '[^[:space:]]'; then echo 'REFUS : nouveau disque deja monte'; exit 1; fi
mkdir -p "$target" "$iso"
for cd in /dev/sr*; do
 if mount -o ro "$cd" "$iso" 2>/dev/null; then
  if test -f "$iso/casper/filesystem.squashfs" && grep -q '18.04.1' "$iso/.disk/info"; then break; fi
  umount "$iso"
 fi
done
test -f "$iso/casper/filesystem.squashfs"
grep -q '18.04.1' "$iso/.disk/info"
echo 'Source Ubuntu 18.04.1 confirmee ; nouveau disque 20 Go distinct du systeme actif'
if ! command -v unsquashfs >/dev/null; then DEBIAN_FRONTEND=noninteractive apt-get install -y squashfs-tools; fi
parted -s "$disk" mklabel msdos
parted -s "$disk" mkpart primary ext4 1MiB 100%
parted -s "$disk" set 1 boot on
udevadm settle
mkfs.ext4 -F -L bagage-externe /dev/sdb1
mount /dev/sdb1 "$target"
cleanup() {
 for path in run sys proc dev; do umount -R "$target/$path" 2>/dev/null || true; done
 umount "$target" 2>/dev/null || true
 umount "$iso" 2>/dev/null || true
}
trap cleanup EXIT
echo 'Extraction du systeme original de ISO...'
unsquashfs -f -d "$target" "$iso/casper/filesystem.squashfs"
uuid=$(blkid -s UUID -o value /dev/sdb1)
printf 'UUID=%s / ext4 defaults 0 1\n' "$uuid" > "$target/etc/fstab"
printf 'bagage-externe\n' > "$target/etc/hostname"
printf '127.0.0.1 localhost\n127.0.1.1 bagage-externe\n' > "$target/etc/hosts"
cp -L /etc/resolv.conf "$target/etc/resolv.conf"
cat > "$target/etc/apt/sources.list" <<'APT'
deb http://archive.ubuntu.com/ubuntu bionic main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu bionic-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu bionic-security main restricted universe multiverse
APT
for path in dev proc sys run; do mount --rbind "/$path" "$target/$path"; mount --make-rslave "$target/$path"; done
# Empêcher les services du système cible de démarrer dans la VM outil.
printf '#!/bin/sh\nexit 101\n' > "$target/usr/sbin/policy-rc.d"
chmod 755 "$target/usr/sbin/policy-rc.d"
chroot "$target" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get update
chroot "$target" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server open-vm-tools python3 wireguard-tools linux-generic-hwe-18.04 grub-pc-bin grub2-common
if ! chroot "$target" id bagagetest >/dev/null 2>&1; then chroot "$target" useradd -m -s /bin/bash -G sudo bagagetest; fi
python3 - "$base/credentials.json" <<'PY' | chroot "$target" chpasswd
import json,sys
print('bagagetest:'+json.load(open(sys.argv[1]))['password'])
PY
mkdir -p "$target/home/bagagetest/.ssh"
cp "$base/id_ed25519.pub" "$target/home/bagagetest/.ssh/authorized_keys"
chmod 700 "$target/home/bagagetest/.ssh"
chmod 600 "$target/home/bagagetest/.ssh/authorized_keys"
chroot "$target" chown -R bagagetest:bagagetest /home/bagagetest/.ssh
mkdir -p "$target/etc/ssh/sshd_config.d"
# Compte de test uniquement : accès SSH par clé, pas de root ni de mot de passe réseau.
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/; s/^#\?PermitRootLogin .*/PermitRootLogin no/' "$target/etc/ssh/sshd_config"
cat > "$target/etc/netplan/99-bagage.yaml" <<'NET'
network:
  version: 2
  renderer: networkd
  ethernets:
    bagage:
      match:
        name: "en*"
      dhcp4: true
NET
rm -f "$target/etc/netplan/01-network-manager-all.yaml"
chroot "$target" systemctl enable ssh open-vm-tools systemd-networkd
chroot "$target" systemctl set-default multi-user.target
rm -f "$target/usr/sbin/policy-rc.d"
chroot "$target" update-initramfs -u -k all
chroot "$target" grub-install --target=i386-pc --recheck "$disk"
printf '\nGRUB_DISABLE_OS_PROBER=true\n' >> "$target/etc/default/grub"
chroot "$target" update-grub
touch "$target/var/lib/bagage-firstboot-ready"
sync
echo 'INSTALLATION TERMINEE - disque autonome, kernel HWE, SSH par cle et outils WireGuard'
