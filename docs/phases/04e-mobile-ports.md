# Phase 4e — Deuxième VM, ports partagés et Internet mobile

## Réalisation

Une seconde VM VMware, `work/phase-04/vm-scan/bagage-scan.vmx`, a été créée comme clone lié d’un instantané de la VM Ubuntu installée depuis l’ISO fourni. Elle possède son propre disque différentiel ; conserver sa VM parent et l’instantané `Base-client-reseau-20261002`. Son nom Linux est `bagage-scan`. Les identifiants restent privés dans `work`.

Le téléphone Samsung fournit une seconde interface USB. Le PC conserve le Wi-Fi domestique. Les adresses publiques de sortie sont différentes. La VM NAT a vérifié que sa sortie HTTPS est identique à la sortie mobile observée et distincte de la sortie domestique. Ces adresses publiques ne sont pas publiées dans le rapport.

## Fermeture des ports du poste : validée

- PostgreSQL Windows : `listen_addresses = 'localhost'`, service redémarré ; écoutes `127.0.0.1` et `::1` sur 5432, `pg_isready` confirme le fonctionnement local.
- `training_pfe` : frontend 80, backend 8080 et PostgreSQL Docker 5005 publiés uniquement sur `127.0.0.1`. Conteneurs actifs ; volumes existants conservés.
- Une règle Windows persistante bloque l’entrée TCP sur ces quatre ports, tous profils. La restriction des écoutes est indispensable : le premier scan VMware restait joignable malgré cette règle seule.
- Le second scan VMware refuse les quatre connexions à l’adresse LAN du poste : **quatre contrôles réussis**.

Le fichier compose indiqué dans les anciens labels Docker n’existe plus. Les services actifs ont été reconstitués par `scripts/Restrict-TrainingBindings.py`, en conservant images, environnement, volumes et réseaux. Le compose obtenu, contenant des secrets, reste exclusivement dans `work/phase-04/training-loopback.compose.json`. Pour redémarrer cette application en conservant les restrictions :

```powershell
Set-Location C:\Users\User\Desktop\fullstack-bagage
docker compose -p training_pfe -f work/phase-04/training-loopback.compose.json up -d --no-build
```

`infra/shared-host-loopback.yaml` est un modèle pour une copie future du compose original ; il n’a pas servi à la reconstitution. Ne pas republier ultérieurement les ports sur `0.0.0.0`.

## Vérification du serveur VPN : validée par le chemin local

La nouvelle VM a passé **12 contrôles supplémentaires** : authentification et accès privé (4), handshake (1), coupure avec le même JWT et refus des routes privées via le vrai site HTTPS Internet (6), puis rétablissement (1). Le point d’entrée WireGuard de cet essai était l’adresse LAN domestique, pas l’adresse publique. Le tunnel est coupé après les tests et les secrets de test retirés par le script.

Cela porte les contrôles et observations réussis à **258** : 242 précédents + 4 ports locaux + 12 contrôles du nouveau client. Les diagnostics Internet échoués ne sont pas ajoutés à ce total.

## Scan Internet mobile : exécuté, fermeture non validée

Le client VM a confirmé sa sortie mobile distincte et testé l’adresse publique domestique. TCP 80 et 5432 étaient inaccessibles ; TCP 8080 acceptait une connexion. Ce premier test s’est arrêté sur cet échec, sans résultat pour 5005. Une tentative HTTP sur 8080 a ensuite été réinitialisée.

Un complément Windows, explicitement lié à l’adresse de l’interface USB et dont la sortie mobile a été vérifiée par HTTPS, a testé les quatre ports sans s’arrêter au premier échec : TCP 80 accepte une connexion, tandis que 5432, 8080 et 5005 sont inaccessibles. Ces différences entre sondes et instants interdisent de déclarer une fermeture publique globale. Le composant répondant n’est pas identifié : les quatre services du PC écoutent seulement sur localhost. Ne pas attribuer les réponses publiques au PC, au routeur ou à un proxy opérateur sans preuve.

Preuves : `docs/preuves/mobile-internet-scan.json` (VM) et `docs/preuves/mobile-windows-scan-complet.json` (complément Windows). Les contrôles de ces suites échouées ne sont pas ajoutés au bilan réussi. Le script VM a été corrigé pour collecter tous les ports lors d’un prochain essai, même en présence d’une connexion acceptée.

## WireGuard Internet : tenté, non validé

L’utilisateur indique avoir redirigé UDP 52820 vers le PC Wi-Fi. Les réglages temporaires Windows sont appliqués avec `scripts/Prepare-MobileInternet.ps1` : entrée UDP sur l’adresse Wi-Fi et route de retour vers la sortie mobile. Une commande initiale a été rejetée par l’approbation automatique, sans motif détaillé ; après présentation du script et nouvelle autorisation explicite de l’utilisateur, son exécution a réussi.

Le profil client vise l’adresse publique domestique. L’accès privé expire sans handshake ; aucun paquet UDP de la tentative mobile n’est observé par le relais. Un datagramme de diagnostic émis directement depuis l’adresse USB mobile n’est pas reçu non plus. Le même serveur fonctionne ensuite via le chemin local. Le blocage Internet n’est donc pas levé.

Prochaine étape : comparer l’adresse WAN affichée par le routeur avec la sortie domestique observée ; vérifier la redirection, le pare-feu du routeur et un éventuel NAT opérateur. L’UPnP domestique ne répond pas et Windows ne fournit aucune collection de redirections. [Référence de l’API Windows de redirection](https://learn.microsoft.com/en-us/windows/win32/api/natupnp/nf-natupnp-istaticportmappingcollection-add).

## Preuves

- `docs/preuves/ports-partages-local.json` et `.txt` : scan réellement exécuté dans la VM.
- `docs/preuves/scan-vm-local-*` : contrôles VPN local et routes publiques via Internet.
- `docs/preuves/mobile-internet-scan.*` : diagnostic Internet échoué, conservé.
- `docs/captures/phase-04e/01-ports-et-mobile.png` : capture directe VMware, sorties réelles du scan local et du diagnostic mobile.
- `docs/captures/phase-04e/02-ports-et-vpn-local.png` : capture directe VMware des ports fermés et des 12 contrôles VPN par le chemin local.

La suite Internet attend les informations WAN du routeur. La VM est arrêtée proprement après les essais ; les secrets de test sont retirés de l’invité. Le tunnel HTTPS et le relais sont arrêtés. `scripts/Cleanup-MobileInternet.ps1` retire la règle UDP et la route temporaires. Les restrictions persistantes des quatre ports partagés sont conservées. La redirection configurée manuellement dans le routeur reste sous le contrôle de l’utilisateur ; elle n’a pas été supprimée automatiquement.
