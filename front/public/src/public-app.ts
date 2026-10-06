import { Component, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { Tracking, statusLabels, errorText } from '../../shared/models';

@Component({ selector: 'app-root', imports: [FormsModule, DatePipe], templateUrl: './public-app.html', styleUrl: './public-app.css' })
export class PublicApp {
  private http = inject(HttpClient);
  code = ''; result = signal<Tracking | null>(null); busy = signal(false); error = signal('');
  labels = statusLabels;
  async search() {
    if (this.busy()) return;
    this.error.set(''); this.result.set(null);
    const code = this.code.trim().toUpperCase();
    if (!/^[A-F0-9]{48}$/.test(code)) { this.error.set('Le code comporte 48 caractères, de 0 à 9 et de A à F. Recopiez le code remis à l’enregistrement.'); return; }
    this.busy.set(true);
    try { this.result.set(await firstValueFrom(this.http.get<Tracking>(`/api/track/${code}`))); }
    catch (e) { this.error.set(errorText(e)); }
    finally { this.busy.set(false); }
  }
}
