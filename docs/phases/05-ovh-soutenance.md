# Phase 5 — VPS OVH et soutenance

## Résultat au 2 octobre 2026

L'application est hébergée sur le VPS OVH Ubuntu 24.04 x86_64 acheté par l'utilisateur : **https://vps-8e16b3fe.vps.ovh.net**. Le serveur dispose d'environ 8 Go de mémoire et 72 Go de disque. La création du compte Oracle gratuit avait été bloquée faute de carte ; ce choix est remplacé par OVH pour un mois.

**174 contrôles automatisés OVH réussis**, en plus des 281 contrôles du laboratoire : 49 métier, 39 Internet Docker, 32 Internet VMware, 26 infrastructure, 10 restauration, 5 Windows natif après redémarrage et 13 IPv6. Les observations navigateur, l'empreinte de la copie de sauvegarde et le renouvellement simulé sont documentés séparément. Les rejeux et les diagnostics échoués ne sont pas ajoutés. Ce total ne constitue pas une mesure de couverture ni une certification de sécurité.

## Architecture réellement déployée

- Docker et k3d 5.9.0 vérifié par son SHA-256 officiel ; k3s `v1.35.5-k3s1`, un seul nœud.
- Images transférées depuis les versions testées du projet : API .NET 8, deux Angular/Nginx, outils réseau et PostgreSQL 16. Aucun registre public ni secret de laboratoire copié.
- Site public : TCP 443, certificat Let's Encrypt reconnu ; port 80 autorisé pour les challenges ACME, sans application HTTP permanente.
- WireGuard : UDP 52820 directement sur l'adresse du VPS. API, PostgreSQL et interface agents sont privés. Interface agents : `https://10.77.0.1:8443`, sur le VPN uniquement, avec une CA privée dédiée à OVH.
- API Kubernetes exposée uniquement à localhost `16443`, services API/agents/DB en ClusterIP, NetworkPolicies et filtrage dans le pod VPN.
- Nouveaux secrets générés sur le serveur, hors Git ; quatre conteneurs applicatifs non-root, fichiers en lecture seule et sans jeton de service account.
- SSH par clé uniquement ; connexion root et mots de passe SSH désactivés après validation de la clé. Le mot de passe du compte OVH n'est pas utilisé.

## Fichiers et commandes exécutés

Dans `C:\Users\User\Desktop\fullstack-bagage`, les images ont été exportées et compressées sous `work/phase-05`, puis envoyées par `scp` avec la clé `work/phase-05/ovh_ed25519`. Le paquet de sources limité aux manifests, scripts et initialisation DB a été extrait dans `/opt/fullstack-bagage`.

Sur Ubuntu :

```bash
sudo apt-get update
sudo apt-get install -y docker.io curl ca-certificates openssl wireguard-tools python3 certbot
sudo apt-get upgrade -y
sudo certbot certonly --standalone --non-interactive --agree-tos --register-unsafely-without-email -d vps-8e16b3fe.vps.ovh.net
sudo bash /opt/fullstack-bagage/scripts/Deploy-Ovh.sh
sudo bash /opt/fullstack-bagage/scripts/Configure-Ovh-Maintenance.sh
sudo certbot renew --dry-run --no-random-sleep-on-renew
sudo bash /etc/letsencrypt/renewal-hooks/deploy/bagage.sh
sudo python3 /opt/fullstack-bagage/scripts/Inspect-Ovh.py
```

Le certificat public obtenu expire le 31 décembre 2026. Le timer Certbot est actif ; son renouvellement a été simulé avec succès. Le hook testé actualise le Secret public-tls et redémarre le déploiement public. Le certificat privé des agents conserve une durée de laboratoire de 90 jours, suffisante pour le mois prévu ; son renouvellement n'est pas automatisé.

Deux corrections de scripts ont été nécessaires : attendre l'apparition du service Windows après installation ; copier les certificats avec `docker cp -L` pour suivre les liens symboliques Let's Encrypt. Elles ont été rejouées avec succès.

## Validations réellement exécutées

Depuis Docker sur le PC Windows, puis depuis la VM Ubuntu dédiée : handshake direct vers `141.94.20.50:52820`, connexion privée, refus sans JWT et avec faux JWT, coupure/rétablissement avec le même JWT et refus des quatre routes métier sur le site public. Les ports TCP **5432, 8080, 8443, 5005, 6443, 16443, 31443, 31820** sont fermés depuis ces clients Internet. Cela ne revendique pas un scan exhaustif de 65 535 ports ni la fermeture du routeur domestique.

Le site public est aussi vérifié en IPv6 : certificat reconnu, huit ports sensibles refusés et quatre routes privées absentes. Un refus TCP explicite UFW a été ajouté pour ces ports en IPv4 et IPv6 après un diagnostic intermittent ; les 13 contrôles passent après correction. Les diagnostics précédents restent exclus du bilan. Preuve : `ovh-ipv6.json`.

Le test de pair inconnu réussit après recréation de l'interface cliente : aucun handshake et API inaccessible. Le premier diagnostic avait lu un horodatage conservé par le noyau après changement de clé sur une interface existante ; il est conservé dans `ovh-inconnu-diagnostic.json` et exclu des succès.

La recette métier passe par le vrai VPN Internet : quatre rôles, cycle complet, pertes, correction motivée, historique, JWT falsifié, limitation des connexions et verrouillage. Les données sont fictives.

Un redémarrage réel du VPS a été effectué après les mises à jour. Les quatre pods sont redevenus prêts automatiquement ; trois bagages étaient présents avant et après. Le bagage de soutenance est toujours trié, avec deux événements, vérifié en HTTPS depuis Windows.

Preuves : `docs/preuves/ovh-metier.json`, `ovh-internet-*.json`, `ovh-vm-*.json`, `ovh-infrastructure.json`, `ovh-windows.json`, `ovh-restauration.txt`, `ovh-apres-redemarrage.txt`, `ovh-sauvegarde-hors-vps.json` et `ovh-bilan.json`.

## Sauvegarde et limites

`bagage-backup.timer` lance chaque jour à **02:15 UTC, soit 03:15 Africa/Lagos**, un dump PostgreSQL privé avec SHA-256, et conserve les sept dernières sauvegardes réussies. Une restauration logique dans une base temporaire distincte a vérifié les cinq tables, leurs empreintes, les droits de l'historique et l'absence d'orphelins ; la base active n'a pas été remplacée.

Une copie manuelle du dernier dump est téléchargée sur le PC sous `work/phase-05/backups/backup-latest.dump`, avec empreinte identique au serveur. Elle reste hors du dossier du rapport. **Le transfert hors VPS n'est pas automatisé.** La haute disponibilité, la perte complète du disque/nœud et la supervision avec alertes continues ne sont pas validées. L'hébergement suffit pour une soutenance dans ce périmètre ; il n'est pas présenté comme une infrastructure aéroportuaire de production.

## Utiliser le projet pendant la soutenance

1. Le suivi public reste disponible lorsque le PC et les VM sont éteints, tant que le VPS et l'abonnement restent actifs. Ouvrir https://vps-8e16b3fe.vps.ovh.net et utiliser le code fictif enregistré dans `docs/preuves/ovh-demo.json`.
2. Sur ce PC, le tunnel Windows **bagage-ovh** est installé et actif. Après un redémarrage du PC, l'activer dans PowerShell administrateur :

```powershell
Start-Service 'WireGuardTunnel$bagage-ovh'
# Après la démonstration, pour le couper :
Stop-Service 'WireGuardTunnel$bagage-ovh'
```

3. Ouvrir **Microsoft Edge** sur `https://10.77.0.1:8443`. La CA OVH est importée dans le magasin personnel Windows et Edge a chargé l'interface sans avertissement. Le navigateur intégré Codex a refusé cette CA ; aucun avertissement n'a été contourné. Sur une autre machine, installer son propre profil VPN et cette CA avant de présenter l'interface.
4. Les comptes fictifs sont dans **`work/phase-05/exchange/comptes-soutenance.json`** : superviseur, enregistrement et tri. L'administrateur initial est dans **`work/phase-05/login/admin.json`**. Ces fichiers sont privés : ne pas les ajouter au rapport, à Git ou aux captures. L'administrateur n'hérite pas des droits métier.
5. Pour administrer le VPS depuis PowerShell Windows 64 bits :

```powershell
& C:\Windows\System32\OpenSSH\ssh.exe -i C:\Users\User\Desktop\fullstack-bagage\work\phase-05\ovh_ed25519 ubuntu@141.94.20.50
```

Dans PowerShell **x86**, remplacer `System32` par `Sysnative`. Le mot de passe SSH initial ne permet plus la connexion ; conserver la clé privée locale protégée.

## Captures réelles

- `docs/captures/phase-05/01-site-public.jpg` : page Angular publique réellement servie par OVH.
- `02-suivi-reel.jpg` : réponse API et historique du bagage fictif sur le site public.
- `03-scan-internet-vm.png` : capture VMware des résultats exécutés dans la VM contre OVH, sans VPN.
- `04-interface-agents-vpn.png` : capture native Edge de l'interface agents par le tunnel Windows. Mode plein écran pour exclure le profil personnel du navigateur.

Ces images sont originales, sans HTML de simulation ni retouche. Le manifeste contient leurs empreintes.

## Fin du mois

Vérifier dans l'espace client OVH la date d'échéance, l'engagement et le renouvellement. La désactivation du renouvellement/résiliation n'a pas été effectuée par l'assistant. Télécharger les sauvegardes et conserver le rapport avant la suppression du VPS ; supprimer le serveur supprime aussi l'hébergement.
