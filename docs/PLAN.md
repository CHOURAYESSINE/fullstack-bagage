# Plan de réalisation et décisions

État courant : phases 0 à 5 réalisées pour la soutenance, 455 contrôles/observations et 38 captures réelles.

## Progression

| Phase | Livrables | État |
|---|---|---|
| 0 — Cadrage | Cahier des charges, arborescence, conventions, [guide](phases/00-cadrage.md) | Réalisé |
| 1 — Fondations | PostgreSQL, API JWT/RBAC, historique, Docker local | Validée en natif et Docker ; voir le guide 01b |
| 2 — Interfaces | Angular public et agents séparés, intégration et tests | Validée localement : 33 contrôles HTTP et 21 navigateur ; [guide](phases/02-frontend.md) |
| 3 — Réseau | WireGuard, firewall, reverse proxy public limité, TLS | Validée en laboratoire Docker : 40 contrôles et 3 captures ; [guide](phases/03-reseau-vpn-tls.md) |
| 4 — Déploiement et rapport | Kubernetes, NetworkPolicy, tests hors VPN, rapport | 281 contrôles et observations réussis ; ports connus du PC sur localhost, WireGuard et exposition applicative Internet validés via relais temporaires ; [complément courant](phases/04f-internet-relais.md) et [rapport](RAPPORT-PROJET.md) |

| 5 — Hébergement OVH | HTTPS public, VPN Internet direct, sauvegarde et reprise | 174 contrôles réussis ; [guide](phases/05-ovh-soutenance.md) |

## Décisions retenues pour la phase 1

- .NET 8 conservé comme demandé ; aucun passage implicite à .NET 9.
- Entity Framework Core avec migrations et fournisseur PostgreSQL Npgsql.
- Hashage des mots de passe avec PasswordHasher d'ASP.NET Core Identity.
- JWT à durée de vie de 15 minutes, validation signature/émetteur/destinataire/expiration.
- Un agent a un rôle ; l'administrateur possède un compte dédié et n'hérite pas
  des permissions métier du superviseur.
- Le passager n'a pas de compte. Son code de suivi aléatoire de 192 bits donne
  uniquement accès au statut et aux horodatages ; garder ce code privé en usage réel.
- Les statuts persistés sont sans accents : `enregistre`, `trie`, `charge`,
  `en_vol`, `livre`, `perdu`. Les libellés Angular seront en français.
- Choix métier : une transition anormale est refusée à l'agent de tri ; le
  superviseur peut l'accepter avec un motif, conservé et marqué comme anomalie.
  Une déclaration `perdu` est permise depuis tout autre statut, conformément
  à la règle « à tout moment ». Une récupération depuis `perdu` nécessite
  une correction motivée du superviseur.
- Historique et statut modifiés dans la même transaction ; concurrence détectée
  par la colonne système PostgreSQL `xmin`.
- Le compte `bagage_app` n'est pas superutilisateur et ne peut ni modifier ni
  supprimer l'historique. Le propriétaire de la base conserve ses pouvoirs :
  il ne s'agit pas d'une preuve d'intégrité contre un administrateur PostgreSQL.

## Architecture à atteindre

```text
Internet -> HTTPS -> frontend public + proxy autorisant seulement /api/track/*
                                      |
                                      v
                                 API privée -> PostgreSQL privé
                                      ^
                                      |
Agents -> WireGuard -> frontend agents + point d'entrée API interne
```

L'API ne doit jamais être publiée intégralement sur Internet. Le proxy public
sera limité à la route de tracking. La connexion, la gestion des utilisateurs,
les vols et les bagages passeront par le point d'entrée VPN. Un JWT valide
ne doit pas contourner cette restriction réseau.

L'écoute locale de phase 1 protège la démonstration sur ce poste ; elle ne
constitue pas une mise en place du VPN. Les contrôles Angular d'hôte/segment
compléteront le firewall, sans le remplacer.

## Captures à produire par phase

1. API : routes, connexion base, refus d'accès, suivi réel — déjà capturés.
2. Angular : recherche passager, connexion agent, tableau de bord et rôles — neuf captures réelles archivées.
3. Réseau : tunnel actif, accès VPN autorisé, refus hors VPN avec JWT valide,
   tracking public toujours disponible. Ne pas montrer de clé WireGuard.
4. Kubernetes : pods prêts, services internes, politiques réseau, test externe.

À chaque phase : écrire un nouveau guide et légender les captures réellement
prises. Les captures des phases futures ne doivent jamais être anticipées
avec des maquettes ou des résultats inventés.




## Clôture de la recette

Toutes les étapes de démonstration sont détaillées dans [AVANCEMENT.md](AVANCEMENT.md) et [le guide de recette finale](phases/04c-recette-finale.md). Le scan Internet distant et WireGuard Internet restent non exécutés ; ne pas les assimiler au test du site public via Quick Tunnel.
