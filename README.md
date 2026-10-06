# Gestion sécurisée des bagages aéroportuaires

Projet de stage de Yessine Choura — IIT Sfax, ARSI.

Répertoire de travail : `C:\Users\User\Desktop\fullstack-bagage`.

## État au 2 octobre 2026

**Phase 5 — Hébergement OVH validé pour la soutenance.** Site public : https://vps-8e16b3fe.vps.ovh.net. WireGuard Internet direct, recette métier, ports sensibles, restauration et reprise après redémarrage vérifiés. **174 contrôles OVH réussis**, en plus des 281 du laboratoire, et **38 captures réelles** au total. Voir [le guide OVH et les accès privés](docs/phases/05-ovh-soutenance.md) et [l’avancement](docs/AVANCEMENT.md). L'abonnement doit rester actif ; aucune résiliation ou modification du renouvellement n'a été effectuée.

La phase 1 est validée en natif et sous Docker : 39 tests fonctionnels, 9 tests de sécurité, 14 contrôles Docker et 2 contrôles de persistance réussis. Les preuves et captures réelles sont conservées dans `docs/`.
La phase 2 Angular est également validée : 33 contrôles d'intégration et 21 vérifications dans le navigateur. La phase 3 est validée dans le laboratoire Docker : WireGuard, firewall et TLS, avec 40 contrôles réussis et trois captures réelles. La phase 4 Kubernetes est validée en laboratoire k3s avec 59 contrôles réussis. Le rapport technique est disponible dans docs/RAPPORT-PROJET.md.

Commencer par [le guide de phase 1](docs/phases/01-fondations.md) et [la validation Docker](docs/phases/01b-validation-docker.md). Docker écoute sur http://127.0.0.1:18080 ; Swagger est désactivé en Production.

## Démonstration Kubernetes — phase 4

Démarrage : `./scripts/Start-Phase04.ps1`. Validation : `./scripts/Test-Phase04.ps1`.
Public : https://localhost:15443 ; WireGuard : UDP 52820 sur loopback.
[Guide Kubernetes](docs/phases/04-kubernetes-rapport.md) · [Rapport technique](docs/RAPPORT-PROJET.md).
Le VPN Windows natif, les clients VMware et le suivi public HTTPS sont validés. PostgreSQL Windows 5432 et training_pfe 80/8080/5005 sont restreints à localhost. Le diagnostic direct domestique échoué est conservé ; la solution par relais UDP a ensuite passé 23 contrôles Internet. Voir [le complément 4f](docs/phases/04f-internet-relais.md).

## Démonstration Compose — phase 3 sécurisée

Exécuter `./scripts/Start-Phase03.ps1`, puis `./scripts/Test-Phase03.ps1`.
Public : https://localhost:14443 ; agents via WireGuard : https://10.77.0.1:8443.
L’autorité TLS locale n’est pas installée dans le magasin Windows. Le client HTTPS Windows la fournit explicitement. WireGuard Windows est installé, testé et arrêté après validation.
Voir [le guide réseau et les captures réelles](docs/phases/03-reseau-vpn-tls.md).

Les instructions HTTP ci-dessous sont historiques : leurs ports sont fermés en mode sécurisé. Ne pas lancer les anciens scripts pour valider la phase 3.

## Interfaces Angular — phase 2 (historique)

Dans PowerShell, depuis ce dossier : `./scripts/Start-Phase02.ps1`.

- Passagers : http://127.0.0.1:14200
- Agents : http://127.0.0.1:14201
- Validation : `./scripts/Test-Phase02.ps1`
- [Guide, résultats et neuf captures réelles](docs/phases/02-frontend.md)

Les comptes de démonstration sont générés par le test ; leurs identifiants sont
dans le fichier privé `work/phase-02-demo-secrets.json`. Ne pas le partager.
Le compte administrateur initial reste disponible avec les identifiants de `.env`.

## Démarrage Docker HTTP historique — phase 1

Démarrer Docker Desktop, puis exécuter `./scripts/Initialize-Docker.ps1`.
Diagnostic : http://127.0.0.1:18080/health/ready. Les commandes de test sont dans le guide 01b.

## Démarrage natif historique

Le port 5080 est actuellement réservé par Windows ; privilégier Docker sur 18080 sur ce poste.

Dans **PowerShell 7**, depuis ce dossier :

```powershell
dotnet tool restore
./scripts/Initialize-Local.ps1
./scripts/Start-Local.ps1 -Documentation
```

Laisser cette fenêtre ouverte. Swagger : http://127.0.0.1:5080/swagger/index.html

Dans une deuxième fenêtre PowerShell 7 :

```powershell
./scripts/Test-Phase01.ps1
```

La base dédiée utilise PostgreSQL 16 installé dans `C:\Program Files\PostgreSQL\16\bin`.
Elle écoute uniquement sur `127.0.0.1:55432`. L'API écoute sur `127.0.0.1:5080`.
Les secrets aléatoires sont dans `work/local-secrets.json`, ignorés par Git.
Ne pas les joindre au rapport. Le script d'initialisation ne réinitialise pas
une base existante et ne remplace pas les comptes existants.

Arrêter les services sans supprimer les données : `./scripts/Stop-Local.ps1`.

## Dossiers

| Dossier | Contenu |
|---|---|
| `back/Bagage.Api` | API .NET 8, modèles, authentification, migrations |
| `database` | Schéma SQL et droits du compte applicatif |
| `front` | Deux applications Angular : public et agents, Dockerfiles et proxys |
| `scripts` | Initialisation, démarrage et tests reproductibles |
| `docs/phases` | Guides de réalisation |
| `docs/captures` | Images de véritables appels dans Swagger |
| `docs/preuves` | Résultats textuels de tests et de vérification |
| `work` | Base locale, journaux et secrets privés, non versionnés |

[Cahier des charges](docs/CAHIER-DES-CHARGES.md) ·
[Plan et décisions](docs/PLAN.md) ·
[Registre des captures](docs/captures/INDEX.md)




