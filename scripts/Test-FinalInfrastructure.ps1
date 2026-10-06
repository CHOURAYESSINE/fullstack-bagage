$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$kc=@('--kubeconfig','work/phase-04/kubeconfig.yaml','--context','k3d-bagage','-n','bagage')
$checks=[Collections.Generic.List[object]]::new()
function Check($test,$ok){$checks.Add(@{test=$test;resultat=$(if($ok){'OK'}else{'ECHEC'})});Write-Host "$(if($ok){'OK'}else{'ECHEC'}) - $test";if(!$ok){throw $test}}
try {
 $pods=kubectl @kc get pods -o json | ConvertFrom-Json
 if($LASTEXITCODE){throw 'Lecture pods impossible'}
 foreach($name in @('public','agents','api','db')){
  $pod=$pods.items | Where-Object {$_.metadata.labels.app -eq $name -and !$_.metadata.deletionTimestamp} | Select-Object -First 1
  Check "$name : pod pret" (@($pod.status.containerStatuses | Where-Object {!$_.ready}).Count -eq 0 -and $pod.status.phase -eq 'Running')
  Check "$name : pas de jeton Kubernetes ni reseau hote" ($pod.spec.automountServiceAccountToken -eq $false -and !$pod.spec.hostNetwork)
  foreach($container in $pod.spec.containers){
   $s=$container.securityContext
   Check "$name : non-root sans elevation, fichiers en lecture seule" ($s.runAsNonRoot -eq $true -and $s.runAsUser -gt 0 -and $s.allowPrivilegeEscalation -eq $false -and $s.readOnlyRootFilesystem -eq $true)
   Check "$name : capabilities supprimees et ressources bornees" ($s.capabilities.drop -contains 'ALL' -and $container.resources.requests.cpu -and $container.resources.limits.memory)
   Check "$name : probe de disponibilite" ($null -ne $container.readinessProbe)
  }
 }
 $services=kubectl @kc get services -o json | ConvertFrom-Json
 foreach($name in @('api','agents','db')){$service=$services.items | Where-Object {$_.metadata.name -eq $name};Check "$name : ClusterIP sans publication externe" ($service.spec.type -eq 'ClusterIP' -and !$service.spec.externalIPs -and !(@($service.spec.ports | Where-Object nodePort).Count))}
 $policies=kubectl @kc get networkpolicies -o json | ConvertFrom-Json
 $deny=$policies.items | Where-Object {$_.metadata.name -eq 'deny-by-default'}
 Check 'Policy refuse entrant et sortant par defaut' ($deny.spec.policyTypes -contains 'Ingress' -and $deny.spec.policyTypes -contains 'Egress' -and !$deny.spec.ingress -and !$deny.spec.egress)
 $dbRole=kubectl @kc exec db-0 -- psql -U bagage_owner -d bagage -At -c "SELECT NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole FROM pg_roles WHERE rolname='bagage_app';"
 Check 'Compte PostgreSQL applicatif sans superuser/creation base/role' ($LASTEXITCODE -eq 0 -and $dbRole -eq 't')
 $rights=kubectl @kc exec db-0 -- psql -U bagage_owner -d bagage -At -c "SELECT has_table_privilege('bagage_app','historique_statuts','INSERT') AND NOT has_table_privilege('bagage_app','historique_statuts','UPDATE') AND NOT has_table_privilege('bagage_app','historique_statuts','DELETE') AND NOT has_table_privilege('bagage_app','historique_statuts','TRUNCATE');"
 Check 'Historique : ajout sans modification/suppression/truncate' ($LASTEXITCODE -eq 0 -and $rights -eq 't')
 $bindings=docker inspect k3d-bagage-serverlb --format '{{json .HostConfig.PortBindings}}' | ConvertFrom-Json
 Check 'Ports cluster publies sur loopback uniquement' (@($bindings.PSObject.Properties.Value | ForEach-Object {$_} | Where-Object HostIp -ne '127.0.0.1').Count -eq 0)
 $images=@($pods.items | ForEach-Object {$_.status.containerStatuses} | Where-Object imageID | ForEach-Object {@{image=$_.image;imageID=$_.imageID}})
 $images | ConvertTo-Json -Depth 4 | Set-Content docs/preuves/recette-images-deployees.json
} finally {
 @{dateUtc=[DateTime]::UtcNow.ToString('o');checks=@($checks)} | ConvertTo-Json -Depth 5 | Set-Content docs/preuves/recette-infrastructure.json
}
