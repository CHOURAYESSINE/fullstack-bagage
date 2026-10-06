# Rapport technique — Gestion sécurisée des bagages aéroportuaires

**État courant — phase 5 OVH :** application hébergée sur https://vps-8e16b3fe.vps.ovh.net, certificat HTTPS reconnu, WireGuard Internet direct et services privés. **174 contrôles OVH réussis**, en plus des 281 précédents, soit 455 observations/contrôles et 38 captures réelles. Recette métier, scans des ports sensibles, restauration et reprise après redémarrage validées. Sauvegarde quotidienne privée et copie manuelle hors VPS ; aucune haute disponibilité ni sauvegarde hors site automatique revendiquée. Les sections suivantes conservent l'historique ; [guide et preuves OVH](phases/05-ovh-soutenance.md).

**Étudiant :** Yessine Choura — IIT Sfax, ARSI  
**Date :** 2 octobre 2026  
**Périmètre :** projet de démonstration, phases 0 à 4 locales puis phase 5 sur un VPS OVH réel pour la soutenance. Les résultats de validation sont détaillés dans les guides et les preuves associées.

## 1. Objectif du projet

Le projet suit le parcours d’un bagage, depuis son enregistrement jusqu’à sa livraison ou sa déclaration de perte. Il sépare le suivi passager public des fonctions des agents. La sécurité repose sur deux contrôles complémentaires : autoriser une action selon le rôle de l’utilisateur et empêcher l’accès au service privé depuis un réseau non autorisé.

Le code, les scripts et les guides sont conservés dans `C:\Users\User\Desktop\fullstack-bagage`. Les démonstrations utilisent des passagers, comptes et vols fictifs. Les fichiers de secrets sont exclus du dossier de rapport.

## 2. Technologies et composants

| Couche | Réalisation |
|---|---|
| API | ASP.NET Core .NET 8, Entity Framework Core 8 et Npgsql |
| Base | PostgreSQL 16, migrations et compte applicatif à privilèges limités |
| Interfaces | Deux applications Angular distinctes, public et agents |
| Authentification | Mot de passe haché, JWT signé à durée limitée, autorisation par rôle |
| Proxy et transport | Nginx, TLS et certificats de laboratoire |
| Accès privé | WireGuard, filtrage iptables et écoute HTTPS sur l’adresse VPN |
| Conteneurs | Docker Desktop Linux et Docker Compose |
| Orchestration | k3s mono-nœud dans k3d ; Deployments, StatefulSet, Jobs et NetworkPolicy |

Les dépendances Angular sont verrouillées dans le fichier lock du projet. Les versions du cluster et les images utilisées sont consignées dans les preuves de phase 4. Le cluster est local et n’a pas été publié sur Internet.

## 3. Modèle métier et données

Les tables principales sont `roles`, `users`, `vols`, `bagages` et `historique_statuts`. Un bagage appartient à un vol. Chaque changement de statut crée un événement daté avec l’agent responsable ; une transition exceptionnelle nécessite le rôle superviseur et un motif.

Le parcours normal est `enregistre → trie → charge → en_vol → livre`. La déclaration de perte est possible depuis un état autre que perdu. Une récupération depuis perdu est une correction motivée du superviseur.

Le statut et son historique sont enregistrés atomiquement. Le contrôle de concurrence PostgreSQL `xmin` évite d’écraser silencieusement une modification concurrente. Le compte applicatif peut ajouter et lire l’historique, sans le modifier ni le supprimer. Cette restriction ne protège pas contre le propriétaire de la base : ce dernier demeure un acteur de confiance.

## 4. Authentification et autorisations

| Acteur | Accès |
|---|---|
| Passager | Suivi public avec un code aléatoire ; aucune identité exposée |
| Agent d’enregistrement | Enregistrement du bagage et consultation autorisée |
| Agent de tri | Consultation et transitions de manutention autorisées |
| Superviseur | Vols, supervision, transitions exceptionnelles motivées |
| Administrateur | Gestion des comptes ; pas d’héritage automatique des actions métier |

Le JWT expire après 15 minutes. L’API vérifie signature, émetteur, destinataire, expiration et état du compte. Les mots de passe utilisent PasswordHasher. Les tentatives de connexion sont limitées et un verrouillage temporaire intervient après des échecs répétés. Le JWT de l’interface agents est conservé en mémoire.

Les boutons masqués dans Angular facilitent l’usage, mais l’API prend la décision d’autorisation. Le contrôle d’origine de l’interface agents complète la protection réseau. Un JWT valide ne donne pas, à lui seul, une route réseau vers le service privé.

## 5. Architecture sécurisée

Le proxy public accepte uniquement le suivi en lecture. Les requêtes publiques vers les comptes, la connexion, les vols et les bagages sont refusées. Les agents passent par WireGuard puis HTTPS vers le proxy privé. PostgreSQL ne possède pas de port accessible publiquement.

Dans Compose, les réseaux edge, public_api, private_api et database isolent les composants. Dans Kubernetes, les NetworkPolicy appliquent un refus entrant et sortant par défaut, puis autorisent les flux nécessaires entre proxys, API, base et DNS.

```text
Passager ─ HTTPS ─ Proxy public ─ Suivi uniquement ─┐
                                                  API ─ PostgreSQL
Agent ─ WireGuard ─ HTTPS ─ Proxy agents ─ JWT/RBAC ┘
```

Le modèle de menace couvre notamment les appels privés depuis le segment public, l’usage d’un JWT valide hors VPN, les opérations avec un rôle insuffisant et les modifications concurrentes. Il ne constitue pas un audit exhaustif, ni une protection contre l’administrateur du poste Docker ou du cluster.

## 6. Réalisation progressive et preuves

| Phase | Livrable et validation |
|---|---|
| 0 | Cahier des charges, arborescence, conventions et décisions |
| 1 | API et PostgreSQL ; 39 tests fonctionnels, 9 de sécurité, 14 Docker et 2 de persistance |
| 2 | Interfaces Angular ; 33 contrôles HTTP et 21 vérifications navigateur |
| 3 | WireGuard, firewall et TLS dans Docker ; 40 contrôles réussis |
| 4 | Déploiement k3s, policies, VPN et persistance ; 59 contrôles réussis en laboratoire local |

Ces nombres correspondent à des suites et scénarios distincts ; ils ne mesurent pas un pourcentage de couverture du code. Les captures sont originales, prises dans Swagger, les interfaces Angular et Docker Desktop. Les résultats textuels et JSON complètent les images.

- [Phase 1 — fondations](phases/01-fondations.md)
- [Phase 1 — validation Docker](phases/01b-validation-docker.md)
- [Phase 2 — interfaces](phases/02-frontend.md)
- [Phase 3 — réseau](phases/03-reseau-vpn-tls.md)
- [Phase 4 — Kubernetes](phases/04-kubernetes-rapport.md)
- [Registre des captures](captures/INDEX.md)

## 7. Déploiement Kubernetes et persistance

Le cluster comporte un nœud k3s. PostgreSQL utilise un StatefulSet et un PVC local-path ; l’API et les interfaces utilisent des Deployments. Les migrations et le compte initial sont créés par des Jobs. Les ressources privées restent en ClusterIP ; seuls HTTPS public et UDP WireGuard ont des NodePort, publiés sur loopback Windows.

Les secrets sont générés localement, chargés dans des objets Secret Kubernetes et chiffrés au repos par k3s. Les pods applicatifs ne reçoivent pas de jeton d’administration Kubernetes. Le kubeconfig reste un fichier privé réservé à la gestion du laboratoire.

Un test remplace le pod PostgreSQL puis vérifie que le bagage et ses deux événements sont conservés. Il vérifie la persistance après remplacement du pod, pas une restauration de sauvegarde ni une perte complète du nœud.

## 8. Problèmes rencontrés et corrections

- L’ancien Docker Desktop ne démarrait pas correctement. La mise à jour officielle a rétabli le moteur ; les détails et preuves sont dans le guide 01b.
- Le port Windows 5080 était réservé. La démonstration Docker a utilisé un autre port local, puis les modes sécurisés ont supprimé cette publication de l’API.
- La politique CSP a nécessité de désactiver l’injection inline des styles critiques lors du build Angular.
- La première création du cluster a dépassé le délai de téléchargement de l’image k3s. Le téléchargement séparé, puis la création du cluster, ont abouti.
- Le remplacement de PostgreSQL a révélé une connexion périmée dans le pool de l’API. Les requêtes GET utilisent désormais au plus trois nouvelles tentatives sur erreurs transitoires. Les écritures ne sont pas rejouées automatiquement, car le résultat d’un commit interrompu peut être ambigu.

Cette dernière correction suit la [stratégie de reconnexion Npgsql](https://www.npgsql.org/efcore/misc/other.html) et tient compte du [risque de répétition des écritures documenté par EF Core](https://learn.microsoft.com/en-us/ef/core/miscellaneous/connection-resiliency).

## 9. Limites de la démonstration

Les phases réseau et Kubernetes ont été réalisées sur un seul poste. Les clients de validation sont de vrais conteneurs externes aux pods Kubernetes ; ils ne représentent pas une seconde machine située sur Internet. Le VPN natif Windows a depuis passé 24 contrôles complémentaires ; le test depuis une VM VMware a également passé 25 contrôles.

Les certificats proviennent d’une autorité locale explicitement fournie aux clients de test. Ils ne sont pas approuvés automatiquement par le navigateur Windows. Une exploitation réelle requiert une gestion des certificats, du renouvellement et de la révocation adaptée.

Le cluster mono-nœud et son stockage local ne procurent pas de haute disponibilité. La recette finale a ajouté une sauvegarde logique restaurée dans une base séparée. Il reste à prévoir sauvegardes hors site avec reprise après perte du nœud, supervision et alertes, stratégie de mises à jour, gestion des comptes d’administration, registre d’images avec versions immuables, tests de charge et audit indépendant. Les logs et probes présents ne constituent pas un système complet de supervision.

## 10. Utilisation pour la soutenance

Présenter d’abord les interfaces de phase 2 et les règles métier, puis les captures de phase 3 montrant qu’un JWT ne remplace pas le VPN. Présenter enfin les ressources Kubernetes, l’expérience NetworkPolicy et le résultat de persistance. Toujours préciser le périmètre local des tests.

Pour reproduire la dernière démonstration, suivre les commandes du guide de phase 4. Ne pas transmettre `.env`, `work/`, un kubeconfig, un export des Secrets ou une configuration WireGuard privée. Les guides, preuves expurgées et captures de `docs/` forment le dossier de rapport partageable.


## Complément Windows et VMware — 2 octobre 2026

Les 24 contrôles Windows natifs ont réussi : HTTPS public, VPN WireGuard, handshake, coupure avec le même JWT, disparition de la route privée et rétablissement. Ils portent le total Kubernetes et Windows à 83 contrôles. Le JWT temporaire a été supprimé et le tunnel est arrêté après les tests. Le client HTTPS vérifie la chaîne et le nom avec la CA locale explicite.

La VM VMware Ubuntu 64-bit (2) a passé 25 contrôles : HTTPS, suivi, restrictions publiques et VPN avec coupure/rétablissement du même JWT. Le total atteint 108 contrôles réussis. Le réseau initial a été rétabli et les accès temporaires supprimés. Deux ports du poste partagé (5432, 8080) restent exposés par d’autres services : le diagnostic initial échoué est conservé et la fermeture globale de ces ports n’est pas validée. Le déploiement bagage ne publie pas ces ports. Voir [le guide complémentaire](phases/04b-windows-vm.md), avec les captures réelles Windows et VMware. Le suivi public a ensuite été testé via une URL Internet Cloudflare temporaire, arrêtée après validation ; le scan distant et WireGuard Internet restent non exécutés.

## Recette finale et état de clôture

La phase 4 et ses compléments regroupent 210 contrôles/observations réussis. Les 102 complémentaires comprennent 49 contrôles métier, 27 de durcissement, 10 de sauvegarde/restauration, 9 HTTP via URL Internet, 3 dans le navigateur, 2 observations de journalisation et 2 audits de dépendances. Le rejeu des 59 contrôles Kubernetes a réussi et n'est pas ajouté deux fois.

La sauvegarde privée a été restaurée dans une base temporaire distincte sur le serveur PostgreSQL du laboratoire. Les cinq tables ont les mêmes nombres et empreintes de lignes ; les droits de l'historique et l'absence d'orphelins ont été vérifiés. La base active n'a pas été remplacée. Ce test n'est pas une reprise après perte du nœud.

Le site public a été atteint par HTTPS via un Quick Tunnel Cloudflare dont l'origine TLS était vérifiée. Le vrai suivi s'affiche et les routes privées restent refusées. Les clients de ce test sont Node et le navigateur Windows ; aucun scan distant ni accès WireGuard Internet n'a été réalisé. Le tunnel est arrêté après essais.

Les audits n'ont signalé aucune vulnérabilité pour les paquets NuGet examinés, transitifs compris, et les dépendances npm de production. Ils ne couvrent pas toutes les images et systèmes.

[Guide final et captures originales](phases/04c-recette-finale.md) · [Avancement complet et limites](AVANCEMENT.md). La démonstration du projet est prête pour la soutenance dans ce périmètre.

## Nouvelle VM Ubuntu issue de l’ISO fourni — phase 4d

Une VM dédiée de 2 Go de RAM, deux vCPU et 20 Go de disque a été installée depuis `F:\ubuntu-18.04.1-desktop-amd64.iso`, dont le SHA-256 correspond au manifeste officiel. Elle démarre sous Ubuntu 18.04.1 avec un noyau HWE 5.4 et les outils SSH, VMware et WireGuard. Le réseau NAT `192.168.233.0/24` est distinct des réseaux Kubernetes et du VPN. La VM existante utilisée temporairement pour l’installation a retrouvé sa configuration initiale, contrôlée par empreinte.

Le nouveau client a passé 25 contrôles réseau/VPN, puis sept contrôles HTTPS publics via Internet avec les CA système Ubuntu. Le même JWT est inaccessible après coupure de WireGuard et accepté après rétablissement. Le suivi Internet réel fonctionne et quatre routes privées sont refusées. Les preuves JSON et trois captures directes de la console VMware sont conservées ; elles affichent des sorties exécutées, sans fabrication HTML.

Le total atteint **242 contrôles et observations réussis**. Le tunnel public et le relais temporaire sont arrêtés ; les règles pare-feu ajoutées pour les essais sont retirées. La nouvelle VM est installée et arrêtée proprement. Elle demeure sur le même poste physique : ces résultats ne remplacent pas un scan depuis un ordinateur distant ni une validation WireGuard sur Internet. [Guide de phase 4d](phases/04d-vm-externe.md).
