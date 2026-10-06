import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { DatePipe } from '@angular/common';
import { Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { Auth } from './auth';
import { Bag, Flight, Agent, roleLabels, errorText } from '../../shared/models';

@Component({ imports: [FormsModule], template: `
  <main class="login-layout"><section class="login-story"><div class="brand"><span class="brand-symbol">↗</span> bagage.</div><div><span class="eyebrow">ESPACE OPÉRATIONS</span><h1>Chaque bagage.<br>Chaque étape.<br><em>Une équipe.</em></h1><p>Enregistrez, suivez et accompagnez les bagages<br>tout au long de leur parcours.</p></div><span class="login-foot">TRAÇABILITÉ · COORDINATION · SÉCURITÉ</span></section><section class="login-form"><div class="login-box"><span class="badge">Accès agents</span><h2>Bienvenue à bord.</h2><p class="muted">Connectez-vous avec votre compte professionnel.</p>
  @if(auth.notice()){<div class="alert" role="status">{{auth.notice()}}</div>}
  <form class="stack" (ngSubmit)="submit()"><div><label for="login">Identifiant</label><input id="login" name="login" [(ngModel)]="login" autocomplete="username" maxlength="120" required></div><div><label for="password">Mot de passe</label><input id="password" name="password" type="password" [(ngModel)]="password" autocomplete="current-password" maxlength="256" required></div><button class="btn" [disabled]="busy()">{{busy()?'Connexion…':'Se connecter'}} <span aria-hidden="true">→</span></button></form>
  @if(error()){<div class="alert" role="alert">{{error()}}</div>}<div class="rule"></div><p class="muted small">Votre compte est géré par l’administrateur. En cas de difficulté, contactez votre responsable.</p></div></section></main>` })
export class Login {
  auth = inject(Auth); private router = inject(Router); login = ''; password = ''; busy = signal(false); error = signal('');
  async submit() { if(this.busy()) return; this.busy.set(true); this.error.set(''); try { await this.auth.login(this.login.trim(),this.password); this.password=''; await this.router.navigateByUrl('/'); } catch(e) { this.error.set(errorText(e)); this.password=''; } finally { this.busy.set(false); } }
}
@Component({ imports: [RouterLink, RouterLinkActive, RouterOutlet, DatePipe], template: `
@if(auth.session(); as current){<a href="#workspace" class="skip">Aller au contenu</a><div class="agent-layout"><aside class="sidebar"><a class="brand" routerLink="/"><span class="brand-symbol" aria-hidden="true">↗</span> bagage.</a><div class="sidebar-caption">ESPACE OPÉRATIONS</div><nav aria-label="Navigation principale"><a routerLink="/" routerLinkActive="active" [routerLinkActiveOptions]="{exact:true}"><span aria-hidden="true">◫</span>Vue d’ensemble</a>@if(auth.has('AgentTri','Superviseur')){<a routerLink="/bagages" routerLinkActive="active"><span aria-hidden="true">▣</span>Bagages</a>}@if(auth.has('AgentEnregistrement','Superviseur')){<a routerLink="/enregistrement" routerLinkActive="active"><span aria-hidden="true">＋</span>Enregistrement</a>}@if(auth.has('AgentEnregistrement','AgentTri','Superviseur')){<a routerLink="/vols" routerLinkActive="active"><span aria-hidden="true">↗</span>Vols</a>}@if(auth.has('Administrateur')){<a routerLink="/comptes" routerLinkActive="active"><span aria-hidden="true">♙</span>Comptes & rôles</a>}</nav><div class="sidebar-bottom"><span class="eyebrow">VOTRE ESPACE</span><strong>{{labels[current.role]}}</strong><small>Chaque action est associée<br>à votre compte.</small></div></aside><div class="agent-main"><header class="agent-header"><span class="muted">Gestion des bagages <span class="breadcrumb">/ Opérations</span></span><div class="session-bar"><span class="avatar" aria-hidden="true">{{auth.loginName().slice(0,1).toUpperCase()}}</span><span><strong>{{auth.loginName()}}</strong><small>{{labels[current.role]}}</small></span><button class="btn ghost" (click)="auth.logout()">Déconnexion</button></div></header><main id="workspace" class="workspace"><router-outlet /></main><footer class="agent-footer"><span>Bagage · Console des opérations</span><span>Session jusqu’à {{current.expiresAt | date:'HH:mm'}}</span></footer></div></div>}` })
export class Shell { auth = inject(Auth); labels = roleLabels; }

@Component({ imports: [RouterLink, DatePipe], template: `
<div class="page-heading topline"><div><span class="eyebrow">VOTRE JOURNÉE, EN UN REGARD</span><h1>Vue d’ensemble</h1><p class="muted">Bonjour {{auth.loginName()}}. Retrouvez vos opérations et vos accès.</p></div><span class="date-chip">{{today | date:'EEEE d MMMM yyyy'}}</span></div>
@if(error()){<div class="alert" role="alert">{{error()}} <button class="link-button" (click)="load()">Réessayer</button></div>}
@if(busy()){<p role="status" class="muted">Chargement de vos données…</p>}
<section class="metrics" aria-label="Indicateurs disponibles">
@if(auth.has('Administrateur')){<div class="metric"><span>Comptes affichés</span><strong>{{users().length}}</strong><small>Liste limitée à 100 comptes</small></div><div class="metric"><span>Comptes actifs affichés</span><strong>{{activeUsers()}}</strong><small>Accès applicatif autorisé</small></div>}
@if(auth.has('AgentTri','Superviseur')){<div class="metric"><span>Bagages affichés</span><strong>{{bags().length}}</strong><small>Les 50 derniers enregistrements</small></div><div class="metric"><span>À traiter sur cette page</span><strong>{{pendingBags()}}</strong><small>Hors livrés et perdus</small></div><div class="metric warning"><span>Perdus sur cette page</span><strong>{{lostBags()}}</strong><small>À examiner avec le service bagages</small></div>}
@if(auth.has('AgentEnregistrement','AgentTri','Superviseur')){<div class="metric"><span>Vols affichés</span><strong>{{flights().length}}</strong><small>Les 100 derniers départs prévus</small></div>}
</section>
<section class="dashboard-grid"><div class="panel"><span class="eyebrow">ACCÈS RAPIDES</span><h2 class="section-title">À vous de jouer.</h2><div class="quick-links">@if(auth.has('AgentTri','Superviseur')){<a routerLink="/bagages"><span class="quick-icon">▣</span><div><strong>Suivre les bagages</strong><small>Filtrer, mettre à jour et consulter l’historique</small></div><span>→</span></a>}@if(auth.has('AgentEnregistrement','Superviseur')){<a routerLink="/enregistrement"><span class="quick-icon">＋</span><div><strong>Enregistrer un bagage</strong><small>Associer un passager et un vol</small></div><span>→</span></a>}@if(auth.has('AgentEnregistrement','AgentTri','Superviseur')){<a routerLink="/vols"><span class="quick-icon">↗</span><div><strong>Consulter les vols</strong><small>Horaires et destinations</small></div><span>→</span></a>}@if(auth.has('Administrateur')){<a routerLink="/comptes"><span class="quick-icon">♙</span><div><strong>Gérer les comptes</strong><small>Créer un accès avec le rôle adapté</small></div><span>→</span></a>}</div></div><aside class="flow-card"><span class="eyebrow">LE PARCOURS BAGAGE</span><h2>Une étape à la fois.</h2><ol><li>Enregistré</li><li>Trié</li><li>Chargé</li><li>En vol</li><li>Livré</li></ol><p>Une correction hors parcours nécessite un superviseur et un motif.</p></aside></section>` })
export class Dashboard {
  auth = inject(Auth); private http = inject(HttpClient); today = new Date(); busy=signal(false); error=signal('');
  bags=signal<Bag[]>([]); flights=signal<Flight[]>([]); users=signal<Agent[]>([]);
  constructor(){void this.load();}
  pendingBags(){return this.bags().filter(b=>!['livre','perdu'].includes(b.statut)).length;}
  lostBags(){return this.bags().filter(b=>b.statut==='perdu').length;}
  activeUsers(){return this.users().filter(u=>u.actif).length;}
  async load(){ this.busy.set(true); this.error.set(''); try {
    if(this.auth.has('Administrateur')) this.users.set(await firstValueFrom(this.http.get<Agent[]>('/api/users')));
    else { this.flights.set(await firstValueFrom(this.http.get<Flight[]>('/api/vols'))); if(this.auth.has('AgentTri','Superviseur')) this.bags.set(await firstValueFrom(this.http.get<Bag[]>('/api/bagages'))); }
  } catch(e){this.error.set(errorText(e));} finally{this.busy.set(false);} }
}

