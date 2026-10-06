import { Injectable, inject, signal } from '@angular/core';
import { HttpClient, HttpInterceptorFn } from '@angular/common/http';
import { CanActivateFn, Router } from '@angular/router';
import { firstValueFrom, catchError, throwError } from 'rxjs';
import { Role, Session } from '../../shared/models';

@Injectable({ providedIn: 'root' })
export class Auth {
  private http = inject(HttpClient); private router = inject(Router);
  session = signal<Session | null>(null); loginName = signal(''); notice = signal('');
  private expiryTimer?: ReturnType<typeof setTimeout>;
  token() { const s = this.session(); return s && Date.parse(s.expiresAt) > Date.now() ? s.accessToken : null; }
  has(...roles: Role[]) { return !!this.token() && roles.includes(this.session()!.role); }
  async login(login: string, password: string) {
    const s = await firstValueFrom(this.http.post<Session>('/api/auth/login', { login, password }));
    this.session.set(s); this.loginName.set(login); this.notice.set('');
    clearTimeout(this.expiryTimer);
    this.expiryTimer = setTimeout(() => this.logout('Votre session a expiré. Veuillez vous reconnecter.'), Math.max(0, Date.parse(s.expiresAt) - Date.now()));
  }
  logout(message = '') { clearTimeout(this.expiryTimer); this.session.set(null); this.loginName.set(''); this.notice.set(message); void this.router.navigateByUrl('/connexion'); }
}
export const sessionGuard: CanActivateFn = () => inject(Auth).token() ? true : inject(Router).createUrlTree(['/connexion']);
export const rolesGuard: CanActivateFn = route => inject(Auth).has(...route.data['roles'] as Role[]) ? true : inject(Router).createUrlTree(['/']);
export const authInterceptor: HttpInterceptorFn = (request, next) => {
  const auth = inject(Auth); const token = auth.token();
  const isPrivateApi = request.url.startsWith('/api/') && !request.url.startsWith('/api/auth/login');
  return next(token && isPrivateApi ? request.clone({ setHeaders: { Authorization: `Bearer ${token}` } }) : request).pipe(catchError(error => {
    if (error.status === 401 && isPrivateApi) auth.logout('Votre session n’est plus valide. Veuillez vous reconnecter.');
    return throwError(() => error);
  }));
};
