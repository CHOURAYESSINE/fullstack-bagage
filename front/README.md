# Interfaces Angular — phase 2

Deux applications autonomes, dans un espace de travail Angular 22.2.1 :

- `public` : suivi passager sans compte, port 14200.
- `agents` : connexion, dashboard, vols, bagages, enregistrement et comptes selon le rôle, port 14201.

Depuis la racine du projet, lancer `./scripts/Start-Phase02.ps1`.
Les Dockerfiles compilent avec Node 24 dans un conteneur, puis servent les
fichiers avec Nginx non-root. Le Node global du poste n'est pas modifié.

Pour développer sans Docker, installer une version Node compatible avec
`package.json`, puis `npm ci` et `npm run start:public` ou `npm run start:agents`.
Les proxys de développement ciblent l'API locale sur 18080.

Le contrôle d'origine dans `agents/public/segment.json` utilise une liste exacte
avant le chargement de l'application agents. Pour le futur réseau VPN, mettre à
jour cette liste et `agents/nginx.conf` avec l'adresse interne retenue. Ces
contrôles ne prouvent pas une présence sur le VPN : le firewall reste nécessaire.

Guide complet : `../docs/phases/02-frontend.md`.

