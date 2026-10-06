#!/bin/bash
set -euo pipefail
cd /opt/fullstack-bagage
# Reject known private ports on the public host, IPv4 and IPv6.
ufw reject proto tcp from any to any port 5432,8080,8443,5005,6443,16443,31443,31820
install -m 755 scripts/Renew-Ovh-Tls.sh /etc/letsencrypt/renewal-hooks/deploy/bagage.sh
cat > /etc/systemd/system/bagage-backup.service <<'EOF'
[Unit]
Description=Sauvegarde privée PostgreSQL Bagage
After=docker.service
Requires=docker.service
[Service]
Type=oneshot
ExecStart=/bin/bash /opt/fullstack-bagage/scripts/Backup-Ovh.sh
UMask=0077
EOF
cat > /etc/systemd/system/bagage-backup.timer <<'EOF'
[Unit]
Description=Sauvegarde quotidienne Bagage
[Timer]
OnCalendar=*-*-* 02:15:00 UTC
Persistent=true
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now bagage-backup.timer
systemctl start bagage-backup.service
systemctl is-active bagage-backup.timer certbot.timer
# Key access has been exercised successfully before disabling password login.
cat > /etc/ssh/sshd_config.d/00-bagage.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
EOF
sshd -t
systemctl reload ssh
echo 'Sauvegarde quotidienne et renouvellement TLS configurés ; SSH par clé uniquement.'
