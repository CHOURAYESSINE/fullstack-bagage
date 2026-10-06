import { bootstrapApplication } from '@angular/platform-browser';
import { provideHttpClient } from '@angular/common/http';
import { PublicApp } from './public-app';
bootstrapApplication(PublicApp, { providers: [provideHttpClient()] }).catch(() => {
  document.body.textContent = 'Le service n’a pas pu démarrer. Veuillez recharger la page.';
});
