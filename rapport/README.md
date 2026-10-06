# Rapport du projet bagages

Source : rapport-bagages.tex. Rapport suivant les trois chapitres du modèle PFA : étude et besoins, conception, réalisation et validation.

Les 37 captures présentées sont appelées depuis ../docs/captures ; chaque figure comporte une légende et un paragraphe explicatif sans champs techniques. Le registre-captures.json donne la phase, le label et le SHA-256 de chaque original. Conserver docs/captures avec la source pour recompiler.

Compilation : dans ce dossier, lancer ./Compiler-Rapport.ps1 avec PowerShell. Le PDF est rapport-bagages.pdf. Les résultats techniques sont ceux du 2 octobre 2026 ; la rédaction ne les rejoue pas.

Avant dépôt : confirmer le nom de l'encadrant et l'année universitaire. Aucun secret n'est inclus.

La capture de diagnostic échoué est exclue du rapport ; les preuves originales restent conservées dans docs. Versions décrites : Angular 22 et PostgreSQL 16. Mise en page : police Fourier et marges fullpage du PFA.

Le chapitre 3 suit désormais le déroulement du travail : fondations API/DB, parcours Angular, VPN, Kubernetes, recette et hébergement OVH. Les captures sont intégrées aux explications ; le bilan est placé après la réalisation.

Les captures sont dimensionnées selon leur format. Les panneaux de résultats Docker sont recadrés sans modifier les originaux ; les cadrages des VM sont conservés. La capture d’accueil très haute est présentée en deux parties. Les trois nouveaux diagrammes complètent l’architecture, et le planning reste exprimé en semaines sans dates de stage.

Les figures de réalisation utilisent un placement souple limité à leur phase. Les dimensions respectent les proportions des captures ; les vues API conteneurisées sont regroupées côte à côte. Cette révision réduit le PDF de 60 à 52 pages sans retirer les 37 captures ni les analyses.
