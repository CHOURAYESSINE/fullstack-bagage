# Phase 4d — Nouveau client Ubuntu depuis l’ISO fourni

## Objectif

Créer une VM VMware dédiée à partir de `F:\ubuntu-18.04.1-desktop-amd64.iso`, puis rejouer les contrôles depuis un sous-réseau distinct de Kubernetes. La VM et ses fichiers privés restent sous `work/phase-04/vm-externe` dans le projet.

## Source et installation

L’empreinte SHA-256 du fichier original est `5748706937539418ee5707bd538c4f5eabae485d17aa49fb13ce2c9b70532433`, conforme au manifeste Ubuntu officiel. Le fichier original n’est pas modifié.

La VM possède deux processeurs virtuels, 2 Go de RAM et un nouveau disque de 20 Go. L’installation graphique automatisée s’étant bloquée, le système de fichiers de l’ISO est extrait sur ce disque par `infra/kubernetes/install_external_vm.sh`. La VM Ubuntu existante sert temporairement d’outil d’installation ; son disque système ne reçoit pas l’installation et sa configuration est sauvegardée pour être rétablie après détachement.

Le noyau HWE, SSH, VMware Tools, Python et les outils WireGuard sont ajoutés depuis les dépôts Ubuntu. Le compte dédié utilise une clé SSH ; les secrets ne figurent pas dans le rapport.

## Réseau et portée

Le réseau NAT VMware VMnet8 est `192.168.233.0/24`, distinct des réseaux Docker/Kubernetes et du VPN `10.77.0.0/24`. Il fournit un vrai client Linux séparé du cluster, sur le même ordinateur physique. Il ne constitue pas une machine distante sur Internet.

## Validation

**Installation et démarrage validés.** Ubuntu 18.04.1 fonctionne sur son propre disque avec le noyau `5.4.0-150-generic`. SSH et VMware Tools sont actifs. La carte apparaît sous le nom `enp0s17` : la configuration initiale `ens33` a été corrigée par une correspondance sur son adresse MAC. L’adresse DHCP obtenue pendant les essais est `192.168.233.137/24`, passerelle `192.168.233.2`.

**32 nouveaux contrôles réussis**, exécutés dans cette VM :

| Groupe | Nombre | Résultat |
|---|---:|---|
| Public, TLS, suivi et ports du projet hors VPN | 13 | Réussis |
| Authentification et accès privé avec VPN | 4 | Réussis |
| Handshake WireGuard | 1 | Réussi, clé masquée |
| Coupure VPN avec le même JWT | 6 | Accès privé bloqué, routes publiques privées refusées |
| Rétablissement VPN avec le même JWT | 1 | Accès privé rétabli |
| HTTPS public via Internet depuis Ubuntu | 7 | Suivi réel et refus de quatre routes privées |

Le total de phase 4 et compléments atteint **242 contrôles et observations**, soit 210 précédents et 32 nouveaux. Il comprend des validations complémentaires sur plusieurs clients ; il ne mesure pas une couverture de code.

Les ports hôte contrôlés ici sont `8443`, `18080` et `14201`. Les ports `5432` et `8080` appartiennent à d’autres services du poste partagé, déjà documentés dans le diagnostic précédent ; leur fermeture globale n’est pas revendiquée.

Le test Internet utilise un Quick Tunnel HTTPS temporaire avec vérification du certificat public par les CA Ubuntu et vérification TLS de l’origine. Le client Ubuntu reste une VM du même poste physique. Le scan depuis un ordinateur distant et WireGuard via Internet ne sont toujours pas exécutés.

## Captures réelles

Ces PNG sont des captures directes du framebuffer VMware. Les deux dernières affichent dans la console Linux les sorties réelles des scripts exécutés dans la VM ; aucune page HTML ni image synthétique n’est utilisée.

- [Premier démarrage Ubuntu](../captures/phase-04d/01-demarrage-ubuntu.png).
- [25 contrôles réseau et VPN](../captures/phase-04d/02-validation-vm.png).
- [7 contrôles Internet et réseau du client](../captures/phase-04d/03-internet-vm.png).

Preuves textuelles et JSON : `docs/preuves/vm-externe-*`. Le manifeste de captures contient leurs empreintes SHA-256.

## État final et ouverture

La VM dédiée est installée et arrêtée proprement après les tests. Dans VMware Workstation, ouvrir `C:\Users\User\Desktop\fullstack-bagage\work\phase-04\vm-externe\bagage-externe.vmx`, puis démarrer. Le compte Linux est `bagagetest` ; son mot de passe généré reste dans le fichier privé `work/phase-04/vm-externe/credentials.json`. L’accès SSH est configuré par clé, sans mot de passe réseau. Le mode de démarrage actuel est console pour les validations ; le système provient de l’image Desktop fournie.

La VM Ubuntu existante est arrêtée et sa configuration restaurée à l’identique, contrôlée par SHA-256. Le disque ajouté est détaché et l’ISO initiale rétablie. Les secrets de test et JWT ont été retirés des invités. Les règles pare-feu temporaires, le relais réseau et le tunnel Internet sont supprimés ou arrêtés. Le projet conserve ses points d’entrée locaux.

Les fichiers `credentials.json`, clés SSH, profils WireGuard et médias personnalisés sous `work` sont privés et exclus du dossier de rapport.
