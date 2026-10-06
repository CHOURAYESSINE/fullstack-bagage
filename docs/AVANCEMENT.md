# Avancement du projet — 2 octobre 2026

**Phase 5 : hébergement OVH et WireGuard Internet direct validés pour la soutenance.** Le site public est disponible sur https://vps-8e16b3fe.vps.ovh.net. Les phases 0 à 4 sont réalisées ; la phase 5 ajoute 174 contrôles réussis sur le VPS distant, soit **455 contrôles/observations au total et 38 captures réelles**. Recette métier, ports sensibles, restauration et redémarrage réel sont vérifiés. Le trajet direct du routeur domestique reste un diagnostic historique distinct ; le VPS n'en dépend pas.

| Ordre | Phase / étape | Niveau atteint |
|---|---|---|
| 1 | 0 — Cadrage | Cahier des charges et décisions réalisés |
| 2 | 1 — Fondations | API, PostgreSQL, JWT/RBAC, historique et Docker validés |
| 3 | 2 — Interfaces | Angular public/agents et intégration validés |
| 4 | 3 — Sécurité réseau | VPN, segmentation et TLS Compose validés |
| 5 | 4 — Kubernetes | Déploiement, policies, scan Docker et persistance validés, suite rejouée |
| 6 | 4b — Clients réels | Windows natif et VMware validés ; mêmes JWT après coupure/rétablissement |
| 7 | 4c — Métier final | Quatre rôles, cycle complet, anomalies et sécurité de connexion validés |
| 8 | 4c — Restauration | Sauvegarde privée restaurée dans une base séparée, cinq tables et droits vérifiés |
| 9 | 4c — Durcissement | Pods prêts/non-root, restrictions, services privés et droits DB vérifiés |
| 10 | 4c — Internet public | Suivi et refus des routes privées validés via URL temporaire, tunnel arrêté |
| 11 | 4c — Preuves et rapport | Guides, captures originales, bilan et dossier partageable finalisés |
| 12 | 4d — Nouvelle VM Ubuntu | ISO vérifiée, installation autonome, sous-réseau NAT distinct, 32 nouveaux contrôles réussis et trois captures réelles |
| 13 | 4e — Seconde VM et ports partagés | Quatre ports locaux fermés au réseau ; 12 contrôles VPN local supplémentaires réussis |
| 14 | 4e — Internet direct domestique | Deux sorties distinctes ; scans échoués et aucun UDP direct reçu ; diagnostics conservés |
| 15 | 4f — Internet via relais UDP | 23 nouveaux contrôles réussis : handshake, accès privé, JWT, coupure, pair inconnu et exposition du site public |
| 16 | 5 — Hébergement OVH | HTTPS reconnu, VPN direct, recette métier, scans, sauvegarde/restauration et redémarrage validés |
| 17 | Soutenance | Accès Windows prêt, trois comptes fictifs, guides et captures ; conserver le VPS pendant la présentation |

La phase 4 et ses compléments totalisent **281 contrôles et observations réussis** : 108 initiaux, 102 de recette finale, 32 sur la première VM dédiée, 16 de ports/VPN local et 23 Internet via relais. Les diagnostics échoués et les rejeux ne sont pas comptés comme nouveaux succès. Ce total ne mesure ni une couverture de code ni un niveau de sécurité absolu.

## Exigences du cahier des charges

| Exigence | Réalisation / validation |
|---|---|
| Tracking sans compte ni donnée personnelle | Interfaces, HTTP, VMware et Internet public |
| Quatre rôles, administration dédiée | API, UI, recette Kubernetes avec refus des actions interdites |
| Cycle, perte, anomalies, traçabilité | 49 contrôles métier finaux et deux observations des journaux |
| Mots de passe hashés, JWT vérifié | API et suites sécurité ; paquets audités |
| Interface agents et API privée hors VPN | Refus réseau Docker/Kubernetes, Windows et VMware ; contrôle Angular complémentaire |
| PostgreSQL privé et compte limité | ClusterIP, policies, privilèges et absence de publication par ce projet |
| Conteneurs et Kubernetes | Compose, Deployments, StatefulSet, Jobs, Secrets et ConfigMaps |
| Persistance et sauvegarde | Remplacement du pod et restauration logique indépendante |
| Rapport et captures réelles | Guides par phase, 38 captures PNG/JPEG originales dans docs/captures |

## Ce qui reste réellement non validé

1. Trajet direct domestique : les scans WAN ont accepté une connexion sur 8080 ou 80 selon la sonde, répondant non identifié ; aucun UDP direct reçu. WireGuard Internet fonctionne maintenant via relais UDP public. Le contrôle des points d’entrée alloués au projet est réussi ; aucun scan global de l’infrastructure partagée des fournisseurs n’est revendiqué.
2. Les ports connus du poste partagé (80, 5432, 8080, 5005) sont maintenant limités à localhost ; leur fermeture depuis la VM sur l’adresse LAN est validée. Cela ne constitue pas un scan exhaustif de tous les ports et interfaces du poste, ni la fermeture du port 8080 observé sur l’adresse publique.
3. Niveau production : haute disponibilité, reprise après perte du nœud, transfert de sauvegardes hors site automatique, supervision/alertes continues et audit indépendant. Une sauvegarde quotidienne privée OVH et une copie manuelle vérifiée sur le PC sont maintenant disponibles.

Ces limites ne sont pas annoncées comme des tests réussis. Le projet de stage de démonstration peut être présenté avec ce périmètre explicite.

## Lire et reproduire

- [Phase 5 — Hébergement OVH, validation et guide de soutenance](phases/05-ovh-soutenance.md). Serveur distant déployé et testé ; 174 contrôles réussis, sans compter les rejeux.

- [Guide final avec commandes dans l'ordre](phases/04c-recette-finale.md)
- [Nouvelle VM depuis votre ISO et tests exécutés](phases/04d-vm-externe.md)
- [Seconde VM, ports partagés et diagnostic Internet mobile](phases/04e-mobile-ports.md)
- [Solution WireGuard Internet via relais UDP et tests réussis](phases/04f-internet-relais.md)
- [Rapport technique](RAPPORT-PROJET.md)
- [Windows et VMware](phases/04b-windows-vm.md)
- [Bilan final JSON](preuves/recette-bilan.json)

Travailler uniquement dans `C:\Users\User\Desktop\fullstack-bagage`. Ne pas lancer les anciens environnements HTTP pour la démonstration sécurisée. Ne jamais joindre work, .env, kubeconfig, archive de sauvegarde ou profils privés au rapport.
