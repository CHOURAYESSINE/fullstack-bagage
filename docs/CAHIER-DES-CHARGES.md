# Guide de projet — Système de gestion des bagages aéroportuaires sécurisé

**Stage d'un mois — Thème sécurité — IIT Sfax, spécialité ARSI**
**Étudiant : Yessine Choura**

---

## 1. Contexte et objectif

Concevoir et déployer une application de gestion du cycle de vie des bagages dans
un environnement aéroportuaire, avec une architecture sécurisée de bout en bout :
authentification par rôle, accès administrateur restreint au réseau VPN interne,
conteneurisation et orchestration.

L'objectif pédagogique n'est pas seulement de livrer une application fonctionnelle,
mais de démontrer une démarche de **sécurisation d'infrastructure** cohérente avec
la spécialité ARSI : segmentation réseau, moindre privilège, durcissement,
traçabilité.

---

## 2. Stack technique

| Composant       | Technologie                          |
|-----------------|---------------------------------------|
| Backend         | .NET 8 (ASP.NET Core Web API)         |
| Frontend        | Angular (dernière version stable)     |
| Base de données | PostgreSQL                            |
| Authentification| JWT (ASP.NET Core Identity ou custom) |
| Conteneurisation| Docker                                |
| Orchestration   | Kubernetes (k3s ou minikube en démo)  |
| Accès admin     | VPN interne (WireGuard recommandé)    |

---

## 3. Acteurs et rôles

| Rôle                     | Description                                                        | Accès réseau requis |
|---------------------------|---------------------------------------------------------------------|----------------------|
| **Passager**              | Suit le statut de son bagage via un code de tracking (lecture seule)| Public / Internet     |
| **Agent d'enregistrement**| Enregistre un bagage, l'associe à un vol et un passager              | VPN uniquement        |
| **Agent de tri/manutention**| Met à jour le statut d'un bagage (trié, chargé, en vol, livré, perdu)| VPN uniquement        |
| **Superviseur**           | Vue globale, gestion des vols, gestion des anomalies, consultation de tous les bagages | VPN uniquement |
| **Administrateur système**| Gestion des comptes utilisateurs et des rôles                       | VPN uniquement, compte dédié |

---

## 4. Règles métier (cycle de vie d'un bagage)

```
enregistré → trié → chargé → en_vol → livré
                                   ↘ perdu (à tout moment)
```

- Un bagage est toujours rattaché à un vol.
- Chaque changement de statut est horodaté et associé à l'agent qui l'a effectué
  (traçabilité obligatoire).
- Un saut d'étape anormal (ex : enregistré → livré directement) doit être
  détectable et loggé comme événement à surveiller.

---

## 5. Exigences fonctionnelles

### 5.1 API Backend (.NET 8)

- `POST /api/auth/login` — authentification, retourne un JWT contenant le rôle
- `GET /api/track/{trackingId}` — **public**, lecture seule, aucune donnée
  personnelle du passager exposée
- `POST /api/vols` — création d'un vol (superviseur)
- `GET /api/vols` — liste des vols (authentifié)
- `POST /api/bagages` — enregistrement d'un bagage (agent d'enregistrement,
  superviseur)
- `GET /api/bagages` — liste/filtrage des bagages (agent de tri, superviseur)
- `PATCH /api/bagages/{id}/statut` — mise à jour de statut (agent de tri,
  superviseur)
- `GET /api/bagages/{id}/historique` — historique complet d'un bagage

Toutes les routes `/api/bagages/*`, `/api/vols/*` et les pages d'administration
Angular doivent être **inaccessibles hors du réseau VPN**, au niveau réseau
(pas seulement applicatif).

### 5.2 Frontend (Angular)

- **Espace public** : formulaire de tracking par code, accessible sans connexion,
  déployé sur le segment réseau public.
- **Espace agents/superviseur** : tableau de bord après connexion, accessible
  uniquement depuis le VPN — l'application elle-même doit refuser de charger
  si elle détecte qu'elle n'est pas servie depuis le segment attendu (contrôle
  applicatif en complément du contrôle réseau, jamais à sa place).
- Gestion des rôles côté UI (les actions non autorisées ne doivent pas
  apparaître, mais la vraie protection reste côté API).

### 5.3 Base de données (PostgreSQL)

Tables principales : `users`, `roles`, `vols`, `bagages`, `historique_statuts`.
- Mots de passe : hashés (jamais en clair, jamais réversibles).
- Connexion à la base : uniquement depuis le réseau privé, jamais exposée
  publiquement.

---

## 6. Architecture réseau cible

```
                         INTERNET (passagers)
                                │
                        [HTTPS uniquement]
                                │
                    ┌───────────────────────┐
                    │  Frontend public       │
                    │  (tracking lecture)    │
                    └───────────┬────────────┘
                                │
                     Sous-réseau PUBLIC
                                │
                    ════════ VPN requis ════════
                                │
                     Sous-réseau PRIVÉ
                                │
          ┌─────────────────────┼─────────────────────┐
          │                     │                       │
  Frontend admin (Angular)  API (.NET 8)         PostgreSQL
  (agents/superviseur)      (bagages, vols)      (jamais exposée)
```

Principes à respecter :
- Le VPN (WireGuard recommandé) est le **seul** point d'entrée vers le
  sous-réseau privé.
- Les règles firewall/Security Group interdisent tout accès direct au
  sous-réseau privé depuis Internet, y compris avec un token JWT valide.
- La base de données n'accepte des connexions que depuis les services
  applicatifs, jamais depuis l'extérieur du sous-réseau privé.

---

## 7. Conteneurisation et orchestration

- Un `Dockerfile` par composant (API .NET, frontend Angular).
- `docker-compose.yml` pour l'environnement de développement local (API +
  frontend + PostgreSQL + réseau isolé).
- Manifests Kubernetes (`Deployment`, `Service`, `Secret`, `ConfigMap`) pour
  un déploiement de démonstration sur un cluster léger (k3s ou minikube) :
  - Les secrets (chaînes de connexion, clé JWT) via `Secret` Kubernetes,
    jamais en dur dans les images.
  - Le `Service` de l'API/frontend admin en `ClusterIP` (pas exposé
    publiquement), atteignable uniquement via le point d'entrée VPN.
  - Le frontend public éventuellement en `Ingress`/`LoadBalancer`.

---

## 8. Plan de réalisation sur 4 semaines

**Semaine 1 — Fondations**
- Modélisation base de données PostgreSQL
- API .NET 8 : authentification JWT, gestion des rôles, endpoints vols/bagages
- Dockerfile + docker-compose pour dev local

**Semaine 2 — Frontend et intégration**
- Frontend Angular : espace public (tracking) + espace admin (login, dashboard)
- Intégration complète front/back, tests fonctionnels des rôles

**Semaine 3 — Sécurisation réseau**
- Mise en place du VPN (WireGuard)
- Segmentation réseau : règles firewall restreignant l'accès admin au VPN
- Durcissement : HTTPS/TLS, gestion des secrets, principe du moindre privilège

**Semaine 4 — Conteneurisation, validation, rapport**
- Manifests Kubernetes, déploiement sur cluster de démonstration
- Tests de validation : confirmer que l'accès admin est bloqué hors VPN
  (scan externe), que le tracking public reste accessible
- Rédaction du rapport (architecture, choix techniques, résultats, limites)

---

## 9. Points de vigilance (à documenter dans le rapport)

- Justifier pourquoi le contrôle d'accès réseau (VPN + firewall) est
  nécessaire **en plus** de l'authentification applicative (défense en
  profondeur).
- Documenter ce qui a été simplifié pour la démonstration (ex : cluster K8s
  mono-nœud au lieu d'un cluster de production) et ce qu'il faudrait ajouter
  en environnement réel (haute disponibilité, sauvegardes, supervision
  continue).
- Si le temps le permet, relier les tentatives d'accès admin hors VPN à un
  système de logging/alerte (lien possible avec un projet antérieur de
  supervision de sécurité).