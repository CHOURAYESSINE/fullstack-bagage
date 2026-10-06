# Phase 4f — WireGuard Internet validé via relais UDP public

## Résultat

**23 nouveaux contrôles réussis depuis la VM `bagage-scan`.** Le total de phase 4 et compléments atteint **281 contrôles et observations**, sans compter deux fois les rejeux. Les tests passent réellement par un endpoint UDP public alloué par Pinggy et une URL HTTPS publique Cloudflare.

Les ports connus du poste partagé sont fermés au réseau : PostgreSQL Windows 5432 écoute sur localhost ; training_pfe 80, 8080 et 5005 sont publiés sur 127.0.0.1. La fermeture LAN a été vérifiée dans la phase 4e. Les conteneurs et les bases continuent de fonctionner en local.

## Solution appliquée

La redirection UDP domestique ne transmettant aucun paquet, un relais UDP temporaire est établi vers `127.0.0.1:52820`, seule destination autorisée dans `scripts/Start-PublicWireGuard.py`. Le relais ne reçoit ni clé privée WireGuard ni identifiants applicatifs. Il transporte les datagrammes ; WireGuard authentifie les pairs et chiffre le trafic entre la VM et le serveur du projet. HTTPS et la vérification de la CA du projet restent actifs dans ce tunnel.

Le SDK officiel **pinggy 0.3.1** est installé sous `work/tools/pinggy-sdk`. Le tunnel est démarré sans jeton ni compte et sans debugger web. Le script l’arrête au bout de quinze minutes au maximum ou dès la présence du fichier `work/phase-04/public-wg/stop`. Le SDK fournit un hostname et un port UDP temporaires, inscrits dans `work/phase-04/public-wg/endpoint.json`. Le client WireGuard utilise ce hostname comme Endpoint.

Les deux VM restent sur le même ordinateur physique. Les interfaces Wi-Fi domestique et partage USB Samsung étaient actives ; la sortie mobile distincte a été vérifiée précédemment. Ici, la présence d’un endpoint public alloué, son adresse réellement utilisée par WireGuard, le handshake et les octets reçus/envoyés confirment le trajet par le relais Internet. Ce n’est pas une validation de la redirection directe du routeur.

Références : [UDP Pinggy](https://pinggy.io/docs/udp_tunnels/), [guide WireGuard](https://pinggy.io/docs/guides/wireguard/), [API Python officielle](https://github.com/Pinggy-io/sdk-python/blob/main/API_DOC.md). La méthode SDK exécutée est utilisée ; ne pas assimiler un tunnel SSH TCP à un transport UDP.

## Contrôles exécutés

| Groupe | Nombre | Résultat |
|---|---:|---|
| Interface privée, authentification, JWT accepté et accès sans JWT refusé | 4 | Réussis via WireGuard Internet |
| Handshake du pair autorisé | 1 | Non nul |
| Coupure avec le même JWT, site public et quatre routes privées | 6 | Privé inaccessible ; routes privées publiques refusées |
| Rétablissement avec le même JWT | 1 | Accès privé rétabli |
| Pair WireGuard inconnu | 2 | Aucun handshake ni accès HTTPS privé |
| Faux JWT dans le VPN autorisé | 1 | HTTP 401 |
| Endpoint réel public et port alloué, handshake, trafic dans les deux sens | 3 | Réussis |
| Scan des quatre routes API privées sur le vrai site public | 4 | HTTP 404 |
| Swagger API sur le site public | 1 | Aucun Swagger exposé |

`/swagger/index.html` renvoie HTTP 200 avec le fallback Angular public, sans Swagger UI ni document OpenAPI. Un premier contrôle exigeait HTTP 404 ; l’inspection de la réponse a confirmé ce fallback. Le contrôle final vérifie l’absence de Swagger privé, sans annoncer un HTTP 404 inexistant.

Les scripts de sonde sont `infra/kubernetes/vm_vpn_test.py` et `infra/kubernetes/probe_public_wg_security.py`. Les fichiers `docs/preuves/internet-wg-*` contiennent les résultats exécutés et le bilan. Le pair inconnu est généré uniquement pour le test, puis supprimé ; les clés et JWT ne sont pas affichés.

## Reproduire dans le projet

Les secrets et profils nécessaires restent dans `work`, exclus du rapport. Le peer 10.77.0.3 est utilisé exclusivement par cette VM pendant les essais : conserver le tunnel Windows arrêté et l’autre VM arrêtée.

```powershell
Set-Location C:\Users\User\Desktop\fullstack-bagage
$taskPython='C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $taskPython -m pip install --target work/tools/pinggy-sdk pinggy==0.3.1
# Lancer dans une console séparée ; attend ensuite les tests.
& $taskPython scripts/Start-PublicWireGuard.py
```

Dans une seconde console, lire `work/phase-04/public-wg/endpoint.json`. Remplacer l’Endpoint du profil privé `work/phase-04/public-wg/bagage-vm.conf` par le hostname et le port UDP nouvellement alloués ; préserver ses clés et AllowedIPs.

```powershell
Set-Location C:\Users\User\Desktop\fullstack-bagage
& 'C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe' start 'C:\Users\User\Desktop\fullstack-bagage\work\phase-04\vm-scan\bagage-scan.vmx' nogui
& .\scripts\Start-InternetDemo.ps1
$env:BAGAGE_VM_VMX='C:\Users\User\Desktop\fullstack-bagage\work\phase-04\vm-scan\bagage-scan.vmx'
```

Le script privé `work/phase-04/public-wg/run-vpn.sh` reprend les commandes exécutées. Avant un rejeu, remplacer son ancienne URL Cloudflare par la nouvelle URL de `work/phase-04/internet-target.json`. Transférer via `scripts/Invoke-ExternalVm.py copyFileFromHostToGuest` le profil, ce script, la CA, les fichiers JSON de contexte et les deux sondes dans `/home/bagagetest/bagage-validation`. Les credentials applicatifs proviennent de `work/phase-04/credentials.json` ; les credentials administrateur invité proviennent de `work/phase-04/vm-externe/credentials.json`. Les deux sont distincts et privés. Le wrapper invité `sudo-run.py` lit ce dernier mot de passe depuis le fichier privé invité, sans l’afficher, pour lancer les scripts Bash.

Exécuter `run-vpn.sh`, puis transférer à nouveau le profil (le premier script le supprime en sortie) et exécuter `run-security.sh`. Copier ensuite leurs JSON et TXT depuis l’invité. Ces commandes et fichiers de travail existent dans l’installation actuelle ; l’archive documentaire seule n’inclut pas les secrets nécessaires au rejeu.

Pour arrêter le relais après les essais :

```powershell
New-Item -ItemType File work/phase-04/public-wg/stop -Force
& .\scripts\Stop-InternetDemo.ps1
```

## Captures et état final

- `docs/captures/phase-04f/01-wireguard-internet.png` : console VMware, résultats réellement exécutés des 12 contrôles VPN/JWT Internet.
- `docs/captures/phase-04f/02-controles-internet.png` : console VMware, résultats des 11 contrôles de sécurité des points d’entrée publics alloués au projet.

Captures directes du framebuffer VMware, aucune fabrication HTML. Empreintes SHA-256 dans le manifeste du dossier. Les secrets de test sont retirés de l’invité, la VM arrêtée proprement, le relais UDP et le tunnel HTTPS arrêtés. Aucune règle supplémentaire de pare-feu entrant n’a été nécessaire pour cette solution ; les protections persistantes des quatre ports partagés sont conservées.

## Portée et limites conservées

La validation Internet du VPN et de l’exposition applicative est réussie **via ces relais temporaires**. Le scan concerne uniquement le port UDP alloué au projet et les routes du site HTTPS alloué au projet. Les autres ports de l’infrastructure partagée Pinggy/Cloudflare ne sont pas des services de ce projet et ne sont pas scannés.

La fermeture globale de l’adresse WAN domestique reste indéterminée : les précédentes sondes acceptaient une connexion TCP sur 8080 ou 80 selon le client et l’instant, alors que les services du PC écoutent en local. Le composant répondant n’est pas identifié. Les services du routeur ou de l’opérateur ne peuvent pas être fermés en créant une autre VM locale. La redirection manuelle du routeur n’est pas utilisée par cette solution. Le diagnostic direct 4e est conservé comme échec, sans être transformé en réussite.

Un service permanent avec endpoint stable, haute disponibilité et engagements de disponibilité ne fait pas partie de cet essai temporaire. Aucun abonnement ni VPS payant n’a été créé.
