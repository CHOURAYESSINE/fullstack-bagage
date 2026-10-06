import { bootstrapApplication } from '@angular/platform-browser';
import { Component } from '@angular/core';
import { provideRouter, RouterOutlet, Routes } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { registerLocaleData } from '@angular/common';
import localeFr from '@angular/common/locales/fr';
import { LOCALE_ID } from '@angular/core';
import { sessionGuard, rolesGuard, authInterceptor } from './auth';
import { Shell, Login, Dashboard } from './shell';
import { BagsPage } from './bags';
import { FlightsPage, UsersPage, RegisterPage } from './forms';

@Component({ selector: 'app-root', imports: [RouterOutlet], template: '<router-outlet />' })
class App {}
const routes: Routes = [
  { path: 'connexion', component: Login },
  { path: '', component: Shell, canActivate: [sessionGuard], canActivateChild: [sessionGuard], children: [
    { path: '', component: Dashboard },
    { path: 'bagages', component: BagsPage, canActivate: [rolesGuard], data: { roles: ['AgentTri', 'Superviseur'] } },
    { path: 'enregistrement', component: RegisterPage, canActivate: [rolesGuard], data: { roles: ['AgentEnregistrement', 'Superviseur'] } },
    { path: 'vols', component: FlightsPage, canActivate: [rolesGuard], data: { roles: ['AgentEnregistrement', 'AgentTri', 'Superviseur'] } },
    { path: 'comptes', component: UsersPage, canActivate: [rolesGuard], data: { roles: ['Administrateur'] } }
  ] },
  { path: '**', redirectTo: '' }
];
export function boot() {
  registerLocaleData(localeFr);
  return bootstrapApplication(App, { providers: [provideRouter(routes), provideHttpClient(withInterceptors([authInterceptor])), { provide: LOCALE_ID, useValue: 'fr' }] });
}
