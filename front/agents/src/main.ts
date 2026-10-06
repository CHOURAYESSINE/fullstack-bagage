// Vérification avant chargement du module de l'espace agents. Complément au réseau, jamais preuve de VPN.
async function start() {
  const response = await fetch('/segment.json', { cache: 'no-store', credentials: 'same-origin' });
  if (!response.ok) throw new Error('Configuration indisponible');
  const config: { allowedOrigins?: unknown } = await response.json();
  if (!Array.isArray(config.allowedOrigins) || !config.allowedOrigins.includes(location.origin)) throw new Error('Segment refusé');
  const { boot } = await import('./bootstrap');
  await boot();
}
start().catch(() => {
  document.title = 'Accès non autorisé — Bagage';
  const main = document.createElement('main'); main.className = 'panel';
  main.style.cssText = 'max-width:600px;margin:12vh auto;padding:40px';
  const title = document.createElement('h1'); title.textContent = 'Accès non autorisé';
  const text = document.createElement('p'); text.textContent = 'Ouvrez l’espace agents depuis l’adresse interne autorisée. Si le problème persiste, contactez votre administrateur.';
  main.append(title, text); document.body.replaceChildren(main);
});
