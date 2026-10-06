# Phase 5 — Hébergement Internet gratuit

**Document préparatoire historique, remplacé par [l'hébergement OVH réellement déployé et validé](05-ovh-soutenance.md).** L'inscription Oracle a été bloquée faute de carte ; l'utilisateur a acheté un VPS OVH pour un mois. Les mentions « accès attendu » ci-dessous décrivent cette préparation antérieure, pas l'état courant.

## Objectif et état

Choix utilisateur : hébergement Internet avec compte gratuit. Cette phase prolonge la démonstration des phases 0 à 4. Les 281 contrôles précédents restent acquis ; ils ne valident pas un serveur cloud encore absent. Les relais Pinggy et Cloudflare temporaires ont été arrêtés.

Solution proposée : une VM Oracle Cloud Always Free, indépendante du PC domestique. Aucun compte, serveur ni abonnement n'a été créé par l'assistant. La création du compte et sa vérification nécessitent l'intervention du titulaire.

## Étape 1 — Obtenir le serveur

1. Créer un compte depuis https://www.oracle.com/cloud/free/ et rester sur les ressources Always Free, sans conversion vers un compte payant.
2. Choisir la région principale avec soin : la capacité gratuite peut être indisponible. Un crédit d'essai limité dans le temps ne garantit pas la gratuité permanente de la ressource.
3. Créer, si disponible, une VM Ubuntu 24.04 ARM `VM.Standard.A1.Flex`, au maximum **2 OCPU et 12 Go de RAM au total**, disque de démarrage 50 Go. Vérifier dans la console l'éligibilité et les quotas avant de créer. Ne pas utiliser les anciennes limites 4 OCPU/24 Go.
4. Fournir une clé SSH publique ; conserver la clé privée hors Git et hors captures. Après création, communiquer uniquement l'adresse publique et le nom d'utilisateur SSH. Aucun mot de passe du compte cloud ne doit être communiqué.

Oracle peut récupérer les instances gratuites inactives. Cette solution ne garantit pas une disponibilité de production. Source officielle consultée le 2 octobre 2026 : https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm

## Étape 2 — Adapter et déployer après obtention de l'accès

Le déploiement actuel est k3d sur Windows et utilise des ports localhost ainsi qu'une autorité de certification de laboratoire. Il ne faut pas copier ce montage tel quel sur Internet.

- Installer et vérifier le moteur de conteneurs et k3s sur le serveur ; conserver la segmentation et les NetworkPolicies.
- Construire les images pour ARM64 si la VM est Ampere : les images locales AMD64 ne sont pas une preuve de compatibilité ARM.
- Générer de nouveaux secrets de production, TLS et clés WireGuard ; ne pas réutiliser les clés/JWT de laboratoire.
- Publier le suivi public en HTTPS avec un certificat reconnu et une adresse stable. Choisir le nom DNS après attribution du serveur.
- Publier uniquement le port UDP WireGuard nécessaire ; garder l'API métier, l'interface agents et PostgreSQL privés. Restreindre SSH à l'administration. Ne pas exposer le port Kubernetes 6443 au public.
- Configurer les sauvegardes, leur rétention et une restauration vérifiée. Une sauvegarde sur le même serveur ne constitue pas une sauvegarde hors site.

Ces opérations seront exécutées sur la machine obtenue, avec des preuves distinctes de la démonstration locale.

## Étape 3 — Validation réelle et captures

Depuis une VM/client utilisant le réseau mobile : vérifier HTTPS et tracking, absence de données personnelles, refus des routes privées sans VPN même avec JWT valide, handshake WireGuard direct vers le serveur, accès autorisé avec VPN, refus des rôles interdits, coupure/rétablissement et refus d'un pair inconnu. Scanner uniquement l'adresse du serveur appartenant au projet pour confirmer la fermeture de PostgreSQL et des ports applicatifs privés. Vérifier ensuite redémarrage, persistance et restauration.

Conserver les sorties originales dans `docs/preuves` et les captures réelles sans secrets dans `docs/captures/phase-05`. **Aucune capture cloud ni validation de cette phase n'est actuellement disponible.**

## Prochaine étape nécessaire

Créer le compte et obtenir la VM gratuite. Si la région n'a pas de capacité ou si l'inscription échoue, documenter l'échec et choisir une autre solution avant de modifier l'architecture. L'hébergement local et les validations Internet via relais restent distincts de cet hébergement cloud.
