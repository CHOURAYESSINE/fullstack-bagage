export const statuses = ['enregistre', 'trie', 'charge', 'en_vol', 'livre', 'perdu'] as const;
export type Status = typeof statuses[number];
export type Role = 'AgentEnregistrement' | 'AgentTri' | 'Superviseur' | 'Administrateur';
export const roleLabels: Record<Role, string> = { AgentEnregistrement: 'Enregistrement', AgentTri: 'Tri & manutention', Superviseur: 'Supervision', Administrateur: 'Administration' };
export const statusLabels: Record<Status, string> = { enregistre: 'Enregistré', trie: 'Trié', charge: 'Chargé', en_vol: 'En vol', livre: 'Livré', perdu: 'Perdu' };
export interface Tracking { trackingId: string; statut: Status; historique: { statut: Status; horodatage: string }[] }
export interface Flight { id: string; numero: string; origine: string; destination: string; departPrevu: string }
export interface Bag { id: string; trackingId: string; volId: string; statut: Status; poidsKg: number; creeLe?: string }
export interface History { id: string; ancienStatut: Status | null; nouveauStatut: Status; horodatage: string; agentId: string; anomalie: boolean; motif: string | null }
export interface Agent { id: string; login: string; role: Role; actif: boolean }
export interface Session { accessToken: string; expiresAt: string; role: Role }
export function errorText(error: unknown): string {
  const e = error as { status?: number; error?: { erreur?: string } };
  if (e.status === 0) return 'Le service est indisponible. Vérifiez la connexion puis réessayez.';
  if (e.status === 401) return 'Connexion refusée ou session expirée. Vérifiez vos identifiants ; le compte peut être temporairement verrouillé.';
  if (e.status === 403) return 'Votre rôle ne permet pas cette opération.';
  if (e.status === 404) return 'Aucun résultat trouvé. Vérifiez la référence saisie.';
  if (e.status === 429) return 'Trop de tentatives. Patientez une minute avant de réessayer.';
  return e.error?.erreur || 'L’opération a échoué. Veuillez réessayer.';
}
