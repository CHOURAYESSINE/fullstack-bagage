# Registre des captures réelles

## Phase 5 — OVH, 2 octobre 2026

- phase-05/01-site-public.jpg : site Angular réellement hébergé sur OVH en HTTPS.
- phase-05/02-suivi-reel.jpg : bagage fictif trié et ses deux événements, réponse du serveur OVH.
- phase-05/03-scan-internet-vm.png : console VMware des tests exécutés depuis la VM contre le VPS distant, API privée inaccessible sans VPN et huit ports TCP sensibles fermés.
- phase-05/04-interface-agents-vpn.png : capture native Edge, page agents chargée par le tunnel WireGuard direct OVH avec certificat privé reconnu. Plein écran pour exclure le profil personnel du navigateur.

Images originales, sans simulation HTML ni retouche ; empreintes dans phase-05/manifest.json. [Guide de reproduction et preuves](../phases/05-ovh-soutenance.md).

## Phase 2 — 1er octobre 2026

Neuf captures originales JPEG dans `phase-02`, sans retouche : accueil public,
suivi réel, connexion, dashboard superviseur, anomalie tracée, reçu bagage,
transition de tri, création de compte et refus d'origine. Les formats étroit
(552 px) et large (1280 px) reflètent les dimensions du navigateur au moment
de la capture. La figure 1 est une capture de page complète.

Les légendes et manipulations sont dans [le guide de phase 2](../phases/02-frontend.md).
Les fichiers et empreintes sont dans `phase-02/manifest.json`. Les noms de
comptes, références et passagers de démonstration sont fictifs. Aucun JWT,
mot de passe ni document HTML de simulation n'est inclus.

## Phase 1 — 1er octobre 2026

Outil : navigateur intégré, capture native JPEG de Swagger UI sur
`http://127.0.0.1:5080/swagger/index.html`. Données fictives créées par les tests.
Aucune retouche du contenu, aucun fichier HTML de simulation.

| Fichier | Manipulation réelle | Résultat et limite |
|---|---|---|
| `phase-01/01-api-routes.jpg` | Ouvrir Swagger de l'API démarrée | Routes disponibles ; ne prouve pas leur autorisation |
| `phase-01/02-postgresql-connecte.jpg` | Exécuter `GET /health/ready` | HTTP 200, connexion DB |
| `phase-01/03-acces-refuse-401.jpg` | Exécuter `GET /api/vols` sans JWT | HTTP 401 ; preuve applicative, pas VPN |
| `phase-01/04-tracking-public.jpg` | Exécuter le suivi du bagage fictif | HTTP 200, parcours livré, aucune identité exposée |

Les réponses sont celles du serveur sous la rubrique **Server response**.
La rubrique **Responses** de Swagger décrit le contrat et ne représente pas
un second appel réseau.

Les heures des en-têtes HTTP sont en GMT/UTC. Les résultats SQL peuvent afficher
le fuseau local de la session PostgreSQL. Les captures des phases suivantes
seront ajoutées après leur réalisation, jamais anticipées avec des maquettes.

## Complément Docker — 1er octobre 2026

| Fichier | Manipulation réelle | Résultat et limite |
|---|---|---|
| `phase-01/05-docker-desktop.jpg` | Docker Desktop, Containers, rechercher fullstack-bagage et développer | Deux services actifs ; API publiée sur 18080 |
| `phase-01/06-api-conteneur.jpg` | Swagger temporaire, GET /health/live, Try it out puis Execute | HTTP 200 et execution: conteneur |
| `phase-01/07-tracking-docker.jpg` | GET /api/track/{trackingId} avec le code fictif sauvegardé | HTTP 200, livré et début de l'historique ; réponse intégrale dans les preuves JSON |

La figure 5 provient de la fenêtre Windows Docker Desktop ; les figures 6 et 7
proviennent du navigateur affichant le vrai Swagger conteneurisé sur 18080.
Les images sont enregistrées sans retouche. Swagger est ensuite désactivé par
le retour à la configuration Production. Les contrôles finaux sont dans
`../preuves/phase-01-docker-infrastructure.txt`.

## Phase 3 — 2 octobre 2026

Trois captures originales JPEG de Docker Desktop, sans retouche :

| Fichier | Manipulation | Résultat |
|---|---|---|
| `phase-03/01-reseau-conteneurs.jpg` | Containers, filtre fullstack-bagage, développer | Sept conteneurs ; ports privés non publiés |
| `phase-03/02-vpn-coupure-retablissement.jpg` | vpn-client, Logs après Test-Phase03.ps1 | Accès avec tunnel, refus après coupure, rétablissement |
| `phase-03/03-acces-hors-vpn.jpg` | outside, Logs après Test-Phase03.ps1 | Même JWT refusé hors VPN, HTTPS public et suivi disponibles |

[Guide et limites du laboratoire](../phases/03-reseau-vpn-tls.md).
Les journaux sont en UTC (1er octobre à 23 h), les captures en date locale (2 octobre).
Aucune clé ni JWT n’est affiché. Le client extérieur est simulé dans Docker.

## Phase 4 — 2 octobre 2026

Quatre captures JPEG originales Docker Desktop, sans retouche : cluster k3s, tests VPN, tests hors VPN avec persistance, sorties kubectl réellement enregistrées. Les légendes, limites et manipulations sont dans [le guide Kubernetes](../phases/04-kubernetes-rapport.md). Les empreintes sont dans `phase-04/manifest.json`.
Les clients sont externes au cluster sur le même poste ; aucune capture ne constitue une preuve de test depuis Internet. Aucun JWT, mot de passe ou clé privée n’est affiché.

## Compléments phase 4 et recette finale

- phase-04/05-vpn-windows-natif.jpg : Docker Desktop, résultats réellement produits par le client Windows natif.
- phase-04/06-validation-vmware.jpg : Docker Desktop, résultats exécutés dans Ubuntu VMware.
- recette/01-suivi-internet.jpg : navigateur sur la vraie URL Internet temporaire, recherche du bagage fictif puis affichage du statut et des deux événements.
- recette/02-restauration-postgresql.jpg : Docker Desktop affichant les résultats de pg_dump/pg_restore et des contrôles PostgreSQL réels.

Images originales sans retouche ni fabrication HTML. Empreintes dans les manifests de chaque dossier. [Guide final et manipulations](../phases/04c-recette-finale.md).

## Phase 4d — Nouvelle VM Ubuntu depuis l’ISO fourni

- phase-04d/01-demarrage-ubuntu.png : framebuffer VMware du premier démarrage sur le nouveau disque.
- phase-04d/02-validation-vm.png : console Linux de la nouvelle VM affichant les 25 contrôles réseau/VPN réellement exécutés.
- phase-04d/03-internet-vm.png : console de la même VM affichant les sept résultats HTTPS via Internet et son sous-réseau NAT.

Ces captures directes n’utilisent pas HTML. Elles prouvent un client Ubuntu réel sur le même hôte physique ; aucun scan depuis une machine distante n’est revendiqué. Empreintes dans `phase-04d/manifest.json`. [Guide et portée des tests](../phases/04d-vm-externe.md).

## Phase 4e — Seconde VM et sortie Internet mobile

- phase-04e/01-ports-et-mobile.png : résultats exécutés du scan LAN réussi et du scan Internet mobile échoué sur 8080.
- phase-04e/02-ports-et-vpn-local.png : seconde VM, ports LAN fermés et contrôles VPN via l’adresse LAN, avec refus des routes privées sur le site public Internet.

Captures directes VMware, sans HTML ni retouche. Les adresses publiques ne sont pas affichées. La VM reste sur le même PC, avec une sortie Internet mobile vérifiée distincte de la sortie domestique. Ces captures ne prouvent pas un handshake WireGuard Internet. [Guide courant](../phases/04e-mobile-ports.md).

## Phase 4f — WireGuard Internet via relais UDP public

- phase-04f/01-wireguard-internet.png : console VMware, 12 contrôles réellement exécutés, handshake Internet, JWT, coupure et rétablissement.
- phase-04f/02-controles-internet.png : console VMware, 11 contrôles réellement exécutés, pair inconnu refusé, endpoint public vérifié et scan des routes publiques du projet.

Captures directes sans HTML ni retouche, avec empreintes dans le manifeste. Les autres ports de l’infrastructure partagée des fournisseurs ne sont pas scannés. [Guide et portée exacte](../phases/04f-internet-relais.md).
