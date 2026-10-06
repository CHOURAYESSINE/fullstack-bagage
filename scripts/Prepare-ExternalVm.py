"""Créer un média unattended privé à partir de l'ISO fournie, sans la modifier."""
import io,json,pathlib,secrets,subprocess,pycdlib,hashlib
root=pathlib.Path(__file__).resolve().parent.parent
work=root/'work/phase-04/vm-externe';work.mkdir(parents=True,exist_ok=True)
source=pathlib.Path('F:/ubuntu-18.04.1-desktop-amd64.iso')
expected='5748706937539418ee5707bd538c4f5eabae485d17aa49fb13ce2c9b70532433'
digest=hashlib.file_digest(source.open('rb'),'sha256').hexdigest()
assert digest==expected,'Empreinte ISO différente'
key=work/'id_ed25519'
if not key.exists():subprocess.run(['C:/Windows/System32/OpenSSH/ssh-keygen.exe','-q','-t','ed25519','-N','','-f',str(key)],check=True)
secretfile=work/'credentials.json'
if secretfile.exists():password=json.loads(secretfile.read_text())['password']
else:
    password='Aa1!'+secrets.token_hex(20)
    secretfile.write_text(json.dumps({'login':'bagagetest','password':password}),encoding='utf-8')
hashed=subprocess.run(['docker','exec','-i','bagage-phase04-preuves','openssl','passwd','-6','-stdin'],input=password+'\n',text=True,capture_output=True,check=True).stdout.strip()
pub=key.with_suffix('.pub').read_text().strip()
firstboot='''#!/bin/sh
set -eu
exec >> /var/log/bagage-firstboot.log 2>&1
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y openssh-server open-vm-tools python3
systemctl enable --now ssh open-vm-tools
touch /var/lib/bagage-firstboot-ready
systemctl disable bagage-firstboot.service
'''
setup=f'''#!/bin/sh
set -eu
mkdir -p /target/home/bagagetest/.ssh
printf '%s\\n' '{pub}' > /target/home/bagagetest/.ssh/authorized_keys
chmod 700 /target/home/bagagetest/.ssh
chmod 600 /target/home/bagagetest/.ssh/authorized_keys
chroot /target chown -R bagagetest:bagagetest /home/bagagetest/.ssh
cp /cdrom/bagage-firstboot.sh /target/usr/local/sbin/bagage-firstboot.sh
chmod 700 /target/usr/local/sbin/bagage-firstboot.sh
cp /cdrom/bagage-firstboot.service /target/etc/systemd/system/bagage-firstboot.service
mkdir -p /target/etc/systemd/system/multi-user.target.wants
ln -sf ../bagage-firstboot.service /target/etc/systemd/system/multi-user.target.wants/bagage-firstboot.service
'''
unit='''[Unit]
Description=Preparation de la VM externe bagage
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/bagage-firstboot-ready
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/bagage-firstboot.sh
TimeoutStartSec=1800
[Install]
WantedBy=multi-user.target
'''
seed=f'''d-i debian-installer/locale string en_US.UTF-8
d-i keyboard-configuration/xkb-keymap select us
d-i keyboard-configuration/layoutcode string us
d-i netcfg/get_hostname string bagage-externe
d-i netcfg/get_domain string local
d-i time/zone string Africa/Lagos
d-i clock-setup/utc boolean true
d-i passwd/user-fullname string Bagage Test
d-i passwd/username string bagagetest
d-i passwd/user-password-crypted password {hashed}
d-i user-setup/allow-password-weak boolean false
d-i user-setup/encrypt-home boolean false
d-i partman-auto/disk string /dev/sda
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string /dev/sda
d-i apt-setup/use_mirror boolean false
ubiquity ubiquity/download_updates boolean false
ubiquity ubiquity/use_nonfree boolean false
ubiquity ubiquity/reboot boolean true
ubiquity ubiquity/success_command string /bin/sh /cdrom/bagage-setup.sh
'''
iso=pycdlib.PyCdlib();iso.open(str(source));buffers=[]
def replace(rr,data):
    record=iso.get_record(rr_path=rr);iso_path=iso.full_path_from_dirrecord(record)
    iso.rm_file(iso_path=iso_path)
    add(iso_path,rr,data)
def add(iso_path,rr,data):
    b=io.BytesIO(data.encode());buffers.append(b)
    iso.add_fp(b,len(data.encode()),iso_path=iso_path,rr_name=rr.rsplit('/',1)[-1])
replace('/isolinux/isolinux.cfg','default bagage\nprompt 0\ntimeout 10\ninclude txt.cfg\n')
replace('/isolinux/txt.cfg','default bagage\nlabel bagage\n  kernel /casper/vmlinuz\n  append initrd=/casper/initrd.lz boot=casper automatic-ubiquity noprompt file=/cdrom/preseed/bagage.seed locale=en_US.UTF-8 keyboard-configuration/layoutcode=us nomodeset console=tty0 console=ttyS0,115200n8 ---\n')
add('/PRESEED/BAGAGE.SEED;1','/preseed/bagage.seed',seed)
add('/BAGAGE_SETUP.SH;1','/bagage-setup.sh',setup)
add('/BAGAGE_FIRSTBOOT.SH;1','/bagage-firstboot.sh',firstboot)
add('/BAGAGE_FIRSTBOOT.SERVICE;1','/bagage-firstboot.service',unit)
print('Construction du média privé automatisé à partir de votre ISO...',flush=True)
iso.write(str(work/'ubuntu-bagage-unattended.iso'));iso.close()
(root/'docs/preuves/vm-externe-iso.json').write_text(json.dumps({'source':str(source),'sha256Source':digest,'verification':'Correspondance avec SHA256SUMS officiel Ubuntu 18.04.1','originalModifie':False,'mediaInstallation':'Copie privee avec preseed, jamais joindre au rapport'},indent=2),encoding='utf-8')
print('Média préparé, aucune valeur de secret affichée.',flush=True)
