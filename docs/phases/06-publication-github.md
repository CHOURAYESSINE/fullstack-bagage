# Phase 6 — Publication du projet sur GitHub

## Objectif
Conserver le code, le rapport et les preuves de réalisation dans un dépôt privé du compte CHOURAYESSINE.

## Dépôt
https://github.com/CHOURAYESSINE/fullstack-bagage

## Préparation
- Dépôt Git initialisé dans le dossier fullstack-bagage, sur la branche main.
- Auteur des commits : CHOURAYESSINE ; email : yessine1choura@gmail.com.
- .env, work/, clés privées, dépendances et fichiers temporaires LaTeX exclus.
- Rapport PDF, source LaTeX, 37 captures présentées et preuves documentées conservés.
- Vérification ciblée des fichiers texte pour détecter des clés privées, JWT et jetons GitHub ; les expressions de génération de clés ne sont pas des clés enregistrées.

## Mise à jour ultérieure
Dans PowerShell, depuis le dossier du projet :

```powershell
git status
git add .
git diff --cached --stat
git commit -m "Mise à jour du projet"
git push
```

Avant chaque commit, vérifier que les fichiers ajoutés ne contiennent aucun secret. Les identifiants restent dans les fichiers privés exclus du dépôt.

## Hébergement
Le dépôt conserve les sources et les livrables. L'application continue de fonctionner sur le VPS OVH ; la publication GitHub ne modifie pas le déploiement.
