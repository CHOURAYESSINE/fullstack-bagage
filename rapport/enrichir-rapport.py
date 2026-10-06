from pathlib import Path
import json,hashlib
r=Path(r'C:\Users\User\Desktop\fullstack-bagage');p=r/'rapport/rapport-bagages.tex';s=p.read_text(encoding='utf-8-sig')
s=s.replace(r'\usepackage{enumitem,xcolor,listings}',r'\usepackage{enumitem,xcolor,listings,float,longtable}')
s=s.replace('Première version de travail -- 6 octobre 2026','Rapport de réalisation -- 6 octobre 2026')
s=s.replace('Cette page sera personnalisée après confirmation de l’encadrement et des contributions.','')
# Expand design using project evidence, not hypothetical production features.
insert=r'''
\subsection{Organisation du code et des responsabilités}
Le backend regroupe les contrats HTTP, les règles métier, l'accès aux données et les contrôles de sécurité. Entity Framework Core décrit les relations et exécute les migrations PostgreSQL. Les applications Angular publique et agents sont compilées séparément afin que le service passager n'embarque pas les écrans internes. Les scripts de démarrage et de validation organisent les expériences ; les manifests déclarent les ressources Kubernetes.
\subsection{Contrat de l'API}
\begin{longtable}{p{5.5cm}p{8cm}}
\caption{Principaux points d'entrée et protections}\\\toprule
\textbf{Route} & \textbf{Usage et contrôle}\\\midrule\endfirsthead
\toprule\textbf{Route} & \textbf{Usage et contrôle}\\\midrule\endhead
\texttt{GET /api/track/\{code\}} & Lecture publique du statut et des événements, sans identité du passager.\\
\texttt{POST /api/auth/login} & Connexion privée, limitation du débit et verrouillage après échecs.\\
\texttt{GET /api/vols} & Consultation autorisée dans le réseau privé.\\
\texttt{POST /api/vols} & Création réservée au superviseur.\\
\texttt{POST /api/bagages} & Enregistrement par un rôle habilité.\\
\texttt{GET /api/bagages} & Liste et filtres selon les permissions.\\
\texttt{PATCH /api/bagages/\{id\}/statut} & Transition normale ou correction motivée, contrôlée par l'API.\\
\texttt{GET /api/bagages/\{id\}/historique} & Consultation privée de la traçabilité.\\\bottomrule
\end{longtable}
Les réponses distinguent notamment l'absence d'authentification (401), un rôle insuffisant (403), une ressource absente (404), un conflit métier ou concurrent (409) et un débit dépassé (429). Le suivi public ne relaie pas les fonctions de connexion, comptes, vols ou modification des bagages.
\subsection{Description du modèle relationnel}
\begin{table}[H]\centering\caption{Entités et liens du modèle métier}
\begin{tabular}{p{4cm}p{9.5cm}}\toprule
\textbf{Entité} & \textbf{Rôle dans le modèle}\\\midrule
\texttt{roles} & Définit les permissions attribuées aux comptes.\\
\texttt{users} & Compte, mot de passe haché et rôle associé.\\
\texttt{vols} & Référence du vol auquel les bagages sont rattachés.\\
\texttt{bagages} & Données d'enregistrement, vol, statut courant et code de suivi aléatoire.\\
\texttt{historique\_statuts} & Événements datés liés au bagage et à l'agent responsable.\\\bottomrule
\end{tabular}\end{table}
La séparation du statut courant et des événements permet une consultation rapide tout en conservant le parcours. Le contrôle de concurrence utilise \texttt{xmin} PostgreSQL. Une modification concurrente ne doit pas effacer silencieusement une autre transition. Les droits SQL de l'historique limitent le compte applicatif à la lecture et à l'ajout.
\subsection{Déploiement et frontière de confiance}
Dans Docker Compose, les réseaux \texttt{edge}, \texttt{public\_api}, \texttt{private\_api} et \texttt{database} limitent les communications. Dans Kubernetes, les services API, agents et base sont de type ClusterIP. Des Deployments exécutent l'API et les interfaces ; un StatefulSet et un volume persistant portent PostgreSQL ; des Jobs réalisent les migrations et l'initialisation.

Les secrets de base de données, de signature JWT et de VPN sont générés hors des images puis fournis par des Secrets. Les conteneurs applicatifs utilisent des comptes non privilégiés, des fichiers en lecture seule et aucun jeton d'administration Kubernetes. L'administrateur de l'hôte et le propriétaire de la base demeurent des acteurs de confiance : ces mécanismes ne protègent pas contre leur contrôle complet du système.
\subsection{Scénario d'utilisation et séquence métier}
Le superviseur crée un vol. L'agent d'enregistrement sélectionne ce vol et saisit un bagage fictif ; l'API crée le bagage et son premier événement, puis fournit un code de suivi. L'agent de tri consulte la liste, choisit le bagage et demande une transition autorisée. L'API contrôle le rôle, le statut précédent et la concurrence avant d'enregistrer l'événement. Le passager utilise enfin son code sur le site public pour lire le statut et les horodatages.
\subsection{Conclusion du chapitre}
La conception sépare les responsabilités des utilisateurs, les chemins réseau et les privilèges des composants. La réalisation suivante vérifie ces choix par des scénarios métier et par des tentatives d'accès depuis différents périmètres.
'''
s=s.replace(r'\chaptertitle{Chapitre 3',insert+'\n'+r'\chaptertitle{Chapitre 3',1)
s=s.replace(r'\subsection{Organisation des tests et validation}'+'\n','')
a=s.index(r'\subsection{Captures à intégrer');b=s.index(r'\subsection{Limites et perspectives}',a)
s=s[:a]+s[b:]
# Each entry: original filename, caption, manipulation, interpretation and scope.
groups=[
('phase-01','Phase 1 : API, PostgreSQL et conteneurisation','01-fondations.md','La première phase établit le modèle de données, le contrat HTTP et les règles d’authentification. Les premiers tests sont natifs ; la seconde série vérifie leur exécution dans Docker. Le refus 401 est un contrôle applicatif, pas encore une preuve de filtrage VPN.',[
('01-api-routes.jpg','Routes exposées par Swagger','Ouvrir Swagger sur le port local 5080 après démarrage de l’API.','Présente les points d’entrée disponibles ; la liste ne prouve pas leurs autorisations.'),
('02-postgresql-connecte.jpg','Disponibilité de la connexion PostgreSQL','Dans Swagger, exécuter GET /health/ready et lire Server response.','HTTP 200 confirme la disponibilité de la connexion à la base à cet instant.'),
('03-acces-refuse-401.jpg','Refus d’une requête sans JWT','Exécuter GET /api/vols sans jeton.','Le serveur répond 401 ; l’authentification applicative est obligatoire.'),
('04-tracking-public.jpg','Suivi public fourni par l’API','Exécuter GET /api/track/{trackingId} avec le code fictif archivé.','Le parcours livré est retourné sans identité du passager.'),
('05-docker-desktop.jpg','Services de fondation dans Docker Desktop','Ouvrir Containers, rechercher fullstack-bagage et développer les services.','API et base sont actives ; la publication 18080 appartient au laboratoire de cette phase.'),
('06-api-conteneur.jpg','Exécution de l’API dans un conteneur','Sur Swagger temporaire du port 18080, exécuter GET /health/live.','HTTP 200 et l’indication conteneur confirment l’environnement d’exécution.'),
('07-tracking-docker.jpg','Suivi et historique depuis Docker','Exécuter le suivi du bagage fictif sur l’API conteneurisée.','L’état livré et l’historique proviennent de PostgreSQL ; les preuves JSON conservent la réponse intégrale.')]),
('phase-02','Phase 2 : interfaces Angular et parcours des rôles','02-frontend.md','Deux applications distinctes sont compilées. Le parcours réel dans le navigateur relie création du vol, enregistrement, tri et suivi public. Les captures sont historiques : un bagage peut avoir changé d’état après la prise de vue. Les comptes et passagers représentés sont fictifs.',[
('01-accueil-public.jpg','Accueil public du suivi passager','Ouvrir le service public sur le port local 14200.','Présente le formulaire sans compte ; la largeur étroite montre le rendu réellement observé.'),
('02-suivi-public.jpg','Consultation du statut Trié','Saisir le code de phase-02-demo.json puis sélectionner Suivre.','Affiche l’état et les événements avant la correction ultérieure du superviseur.'),
('03-connexion-agents.jpg','Redirection vers la connexion agents','Ouvrir /bagages sans session sur le service agents 14201.','La garde de navigation conduit au formulaire ; les champs sont vides.'),
('04-dashboard-superviseur.jpg','Tableau de bord du superviseur','Se connecter avec le compte fictif superviseur.','Les accès métier sont visibles et le menu comptes est absent. Les indicateurs portent sur les données chargées, pas sur des totaux globaux.'),
('05-anomalie-historique.jpg','Correction exceptionnelle et historique','Filtrer le vol UI2001409, ouvrir le bagage et effectuer la correction vers Livré avec motif.','La correction conserve le motif, l’agent et le caractère anormal de la transition.'),
('06-enregistrement-recu.jpg','Enregistrement et reçu de suivi','Avec le rôle d’enregistrement, sélectionner un vol et enregistrer un passager fictif.','Le reçu confirme la création et fournit le code de suivi public.'),
('07-role-tri.jpg','Transition effectuée par l’agent de tri','Avec AgentTri, ouvrir le bagage et le passer à Trié.','La confirmation et l’historique traduisent la mise à jour persistée.'),
('08-creation-compte.jpg','Création d’un compte par l’administrateur','Créer un compte fictif avec Administrateur.','Le formulaire est réinitialisé et la confirmation est visible sans mot de passe affiché.'),
('09-origine-refusee.jpg','Contrôle applicatif de l’origine','Ouvrir localhost.:14201, origine absente de la liste autorisée.','Le module agents refuse de charger. Ce résultat complète la sécurité, mais ne démontre pas un VPN.')]),
('phase-03','Phase 3 : segmentation, TLS et WireGuard dans Docker','03-reseau-vpn-tls.md','Cette phase distingue le droit applicatif de l’accès réseau. Les clients sont des conteneurs sur le poste de développement : les résultats prouvent le laboratoire Docker et ne sont pas encore des essais sur Internet.',[
('01-reseau-conteneurs.jpg','Organisation des conteneurs réseau','Dans Docker Desktop, filtrer fullstack-bagage puis développer.','Les sept conteneurs sont présents et les ports privés ne sont pas publiés directement.'),
('02-vpn-coupure-retablissement.jpg','Accès privé, coupure et rétablissement du tunnel','Après Test-Phase03.ps1, ouvrir les Logs du client vpn-client.','L’accès fonctionne avec tunnel, échoue après coupure puis reprend avec le même JWT.'),
('03-acces-hors-vpn.jpg','Client extérieur au VPN dans le laboratoire','Ouvrir les Logs du client outside après les tests.','Le JWT valide ne suffit pas à atteindre le service privé ; le HTTPS public et le suivi restent disponibles.')]),
('phase-04','Phase 4 : Kubernetes, persistance et clients natifs','04-kubernetes-rapport.md','Le déploiement k3s remplace la composition locale tout en conservant les frontières public/privé. Les premiers clients sont externes aux pods sur le même poste ; Windows et VMware étendent ensuite le périmètre sans constituer, à ce stade, une preuve de tunnel Internet.',[
('01-cluster-k3s.jpg','Cluster k3s dans k3d','Dans Containers, filtrer k3d-bagage.','Montre le nœud et la publication du proxy local ; le cluster demeure mono-nœud.'),
('02-vpn-kubernetes.jpg','WireGuard et services privés du cluster','Ouvrir les Logs de bagage-validation-vpn-client-1.','Les résultats consignent le handshake, la coupure et le rétablissement du même JWT.'),
('03-hors-vpn-persistance.jpg','Restrictions et persistance Kubernetes','Ouvrir les Logs de bagage-validation-outside-1.','Les tests contrôlent le refus privé, le suivi public, les policies et la conservation via PVC. Il ne s’agit pas d’une restauration après perte du disque.'),
('04-ressources-kubernetes.jpg','Ressources observées avec kubectl','Ouvrir les Logs de bagage-phase04-preuves.','Le conteneur auxiliaire lit les sorties kubectl archivées ; il n’est pas un composant métier.'),
('05-vpn-windows-natif.jpg','Validation avec le client Windows natif','Consulter dans Docker Desktop le lecteur des résultats Windows archivés.','Les commandes ont été exécutées sur Windows ; Docker sert uniquement de lecteur de preuves.'),
('06-validation-vmware.jpg','Validation depuis Ubuntu VMware','Consulter le lecteur des sorties exécutées dans Ubuntu via VMware Tools.','La VM est un véritable client distinct de l’application, mais reste sur le même poste physique.')]),
('recette','Recette : suivi Internet temporaire et restauration','04c-recette-finale.md','La recette ajoute le cycle métier complet, le durcissement et une restauration logique indépendante. L’URL publique temporaire utilisée ici a été arrêtée après les essais ; elle n’est pas l’hébergement final.',[
('01-suivi-internet.jpg','Suivi public par URL Internet temporaire','Ouvrir l’URL HTTPS du relais temporaire et rechercher le bagage fictif.','Le navigateur affiche le statut et deux événements réels. Cette figure ne prouve pas un tunnel WireGuard Internet.'),
('02-restauration-postgresql.jpg','Restauration logique vérifiée','Ouvrir dans Docker Desktop les résultats réels de pg_dump et pg_restore.','Les tables et empreintes sont contrôlées dans une base distincte sans remplacer la base active ; le test reste sur le même serveur.')]),
('phase-04d','Phase 4d : installation d’une VM de test dédiée','04d-vm-externe.md','La nouvelle VM est installée depuis l’ISO Ubuntu fourni, avec son propre disque et son réseau NAT. Elle permet de tester un système invité réel ; la présence sur le même hôte ne suffit pas à prouver une sortie Internet indépendante.',[
('01-demarrage-ubuntu.png','Premier démarrage de la VM Ubuntu','Démarrer la VM depuis son nouveau disque après installation.','Le framebuffer VMware montre le système réellement installé ; Ubuntu 18.04 sert uniquement de client de laboratoire historique.'),
('02-validation-vm.png','Contrôles réseau et VPN dans la VM','Exécuter les tests du guide puis afficher leurs résultats dans la console Linux.','Les 25 contrôles portent sur le réseau, le tunnel et les restrictions avec le même JWT.'),
('03-internet-vm.png','HTTPS public depuis la VM dédiée','Exécuter les sept contrôles publics via l’URL temporaire et afficher le sous-réseau NAT.','Vérifie le client HTTPS Ubuntu ; ne prouve pas encore un handshake WireGuard par Internet.')]),
('phase-04e','Phase 4e : ports partagés et réseau mobile','04e-mobile-ports.md','La seconde VM et la sortie mobile servent à séparer les trajets réseau. Le diagnostic initial échoué est conservé. Les services Windows étrangers au projet ont ensuite été restreints à localhost ; les réponses du routeur ne sont pas attribuées sans preuve à ces services.',[
('01-ports-et-mobile.png','Diagnostic LAN et Internet mobile','Afficher le scan LAN et le scan Internet réalisés depuis la seconde VM.','Le LAN passe, mais le scan mobile reçoit une réponse sur 8080. Cette figure documente un échec historique, pas une validation réussie.'),
('02-ports-et-vpn-local.png','Ports LAN fermés et VPN local','Après restriction des services, exécuter les contrôles LAN et VPN puis les routes publiques.','Les résultats passent sur le LAN ; aucun handshake WireGuard Internet n’est revendiqué par cette capture.')]),
('phase-04f','Phase 4f : tunnel Internet par relais UDP','04f-internet-relais.md','Un relais UDP public a rendu possible la démonstration Internet sans dépendre de la redirection du routeur domestique. Le relais est temporaire et a été arrêté. Le VPS OVH remplacera ensuite ce mécanisme.',[
('01-wireguard-internet.png','WireGuard Internet avec relais public','Exécuter dans VMware les douze contrôles du guide puis afficher la console.','Les résultats vérifient handshake, JWT, coupure et rétablissement via le relais.'),
('02-controles-internet.png','Restrictions et refus d’un pair inconnu','Exécuter les onze contrôles complémentaires et afficher les résultats VMware.','Le pair inconnu est refusé et les routes publiques sont vérifiées. Les autres services du fournisseur partagé ne sont pas scannés.')]),
('phase-05','Phase 5 : hébergement OVH et validation Internet directe','05-ovh-soutenance.md','Le VPS Ubuntu 24.04 héberge le site public avec certificat reconnu et offre un endpoint WireGuard direct sur UDP 52820. Les 174 contrôles OVH complètent les 281 observations de phase 4 et recette. Les diagnostics échoués et les rejeux ne sont pas ajoutés.',[
('01-site-public.jpg','Application publique hébergée sur OVH','Ouvrir https://vps-8e16b3fe.vps.ovh.net dans le navigateur.','La page Angular est réellement servie par le VPS en HTTPS ; l’hébergement ne dépend plus du PC.'),
('02-suivi-reel.jpg','Suivi du bagage fictif sur OVH','Saisir le code fictif de ovh-demo.json puis sélectionner Suivre.','Le statut Trié et deux événements proviennent du serveur OVH. L’identité du passager n’apparaît pas.'),
('03-scan-internet-vm.png','Scan Internet du VPS sans VPN','Depuis la VM, désactiver le tunnel, exécuter la série off puis afficher les quinze résultats.','Les accès privés échouent et les huit ports TCP sensibles sont filtrés. Ce scan n’est pas exhaustif de tous les ports.'),
('04-interface-agents-vpn.png','Interface agents atteinte par WireGuard OVH','Activer bagage-ovh sur Windows puis ouvrir https://10.77.0.1:8443 dans Edge.','La page de connexion charge avec le certificat privé reconnu. La capture prouve le chargement de l’interface, pas une session métier déjà authentifiée.')])]

def esc(t):
 return ''.join({'\\':r'\textbackslash{}','&':r'\&','%':r'\%','$':r'\$','#':r'\#','_':r'\_','{':r'\{','}':r'\}','~':r'\textasciitilde{}','^':r'\textasciicircum{}'}.get(c,c) for c in t)
gallery=[r'\subsection{Réalisation détaillée et preuves visuelles}', 'Les captures ci-dessous sont les fichiers originaux des phases de réalisation. Chaque figure est associée à une manipulation et à une interprétation. Les résultats intégraux restent dans les preuves textuelles et JSON ; une capture partielle de journal ne les remplace pas. Les empreintes des originaux sont conservées dans les manifests.']
registry=[]
for folder,title,guide,intro,entries in groups:
 gallery += [r'\clearpage',r'\subsubsection{'+esc(title)+'}',esc(intro),r'\par\medskip\textbf{Guide de reproduction :} \texttt{\detokenize{docs/phases/'+guide+'}}.']
 for i,(name,caption,action,meaning) in enumerate(entries):
  image=r/'docs/captures'/folder/name;assert image.exists(),image
  label='fig:'+folder+'-'+str(i+1)
  gallery += [r'\begin{figure}[H]',r'\centering',r'\includegraphics[width=0.96\linewidth,height=0.46\textheight,keepaspectratio]{../docs/captures/'+folder+'/'+name+'}',r'\caption{'+esc(caption)+'}',r'\label{'+label+'}',r'\end{figure}',r'\noindent\textbf{Manipulation (figure~\ref{'+label+'}) :} '+esc(action)+r'\par',r'\noindent\textbf{Utilisation dans le rapport :} '+esc(meaning)+r'\par',r'\noindent\textbf{Original :} {\footnotesize\texttt{\detokenize{docs/captures/'+folder+'/'+name+'}}}.\par\medskip']
  registry.append(dict(fichier=folder+'/'+name,label=label,phase=title,manipulation=action,interpretation=meaning,sha256=hashlib.sha256(image.read_bytes()).hexdigest()))
assert len(registry)==38
actual={x.relative_to(r/'docs/captures').as_posix() for x in (r/'docs/captures').rglob('*') if x.suffix.lower() in ['.jpg','.png']};assert actual=={x['fichier'] for x in registry}
s=s.replace(r'\subsection{Limites et perspectives}','\n'.join(gallery)+'\n'+r'\subsection{Limites et perspectives}',1)
s=s.replace(r'\fronttitle{Annexe : preuves et rédaction à poursuivre}',r'\fronttitle{Annexe : exploitation et registre des preuves}')
start=s.index('À compléter : identité');end=s.index(r'\end{document}',start)
s=s[:start]+r'''
\subsection*{Procédure de démonstration}
Ouvrir le site public OVH, saisir le code fictif archivé et observer le statut. Sur le PC de démonstration, activer le tunnel Windows puis ouvrir l'interface agents dans Edge. Les identifiants fictifs sont conservés dans les fichiers privés du projet et ne sont pas inclus ici. Utiliser ensuite chaque rôle pour montrer les actions autorisées, une transition normale et une correction motivée.
\begin{lstlisting}
Start-Service 'WireGuardTunnel$bagage-ovh'
# Apres la demonstration :
Stop-Service 'WireGuardTunnel$bagage-ovh'
\end{lstlisting}
Ces commandes sont exécutées dans PowerShell administrateur. Le certificat privé et le profil VPN sont déjà installés sur le poste de démonstration. Un autre client nécessite un profil et une autorité de confiance adaptés.
\subsection*{Maintenance et fin de l'hébergement}
Le serveur réalise un dump quotidien privé et conserve sept sauvegardes réussies. Une copie hors VPS doit être téléchargée manuellement ; la restauration complète après perte du nœud reste à préparer. Vérifier l'échéance et le renouvellement du VPS dans le compte OVH avant la fin du mois prévu. La suppression du VPS supprime le service ; conserver les sources et les sauvegardes auparavant.
\subsection*{Compilation du rapport}
Le fichier source reste \texttt{rapport-bagages.tex}. MiKTeX, déjà installé sur le poste, produit le PDF avec trois passes de pdfLaTeX par \texttt{Compiler-Rapport.ps1}. L'expansion des polices microtype a été désactivée pour éviter une incompatibilité avec les polices présentes. L'aperçu intégré de l'application reste bloqué par une erreur de répertoires du moteur ; cette limite est distincte de la compilation MiKTeX réussie.
\subsection*{Informations académiques}
Le nom de l'encadrant et l'année universitaire doivent être confirmés avant dépôt. Les autres auteurs et l'encadrant du PFA précédent n'ont pas été attribués à ce projet. La mise en page conserve le format A4, le corps de onze points, l'interligne un et demi, les titres centrés et les en-têtes du modèle fourni.
\clearpage
\phantomsection\addcontentsline{toc}{section}{Références du projet}
\begin{thebibliography}{99}
\bibitem{cdc} Yessine Choura, \textit{Cahier des charges : système de gestion des bagages aéroportuaires sécurisé}, fichier \texttt{docs/CAHIER-DES-CHARGES.md}.
\bibitem{guides} \textit{Guides de réalisation des phases 0 à 5}, dossier \texttt{docs/phases}, septembre--octobre 2026. Commandes, résultats observés et limites.
\bibitem{captures} \textit{Registre des captures originales et manifests SHA-256}, dossier \texttt{docs/captures}, 1er--2 octobre 2026.
\bibitem{bilan} \textit{Bilan des validations OVH}, fichier \texttt{docs/preuves/ovh-bilan.json}, 2 octobre 2026. Les preuves individuelles détaillent les contrôles réussis et les diagnostics exclus.
\bibitem{modele} \textit{Rapport PFA fourni par l'étudiant}, fichier \texttt{rapport-pfa.tex}. Référence de structure et de présentation uniquement.
\end{thebibliography}
''' + s[end:]
p.write_text(s,encoding='utf-8',newline='\n')
(r/'rapport/registre-captures.json').write_text(json.dumps(registry,ensure_ascii=False,indent=2),encoding='utf-8')
print('Rapport enrichi : 38 captures originales intégrées, avec manipulation, interprétation et référence.')
