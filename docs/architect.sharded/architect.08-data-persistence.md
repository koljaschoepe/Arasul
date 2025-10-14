# Shard 08: Datenpersistenz

- Auth/Sessions/Audit: SQLite (MVP) auf Device mit `PRAGMA journal_mode=WAL;`. Für den MVP keine PostgreSQL-Instanz. Backups per konsistenter Dateikopie (WAL beachten) oder MinIO-Sync.
- Audit-Daten: 30 Tage lokal in SQLite; ältere Einträge werden in MinIO archiviert.
- MinIO: Objektspeicher lokal; S3-kompatible Endpunkte via Caddy.
- Backups: lokal exportierbar (USB/NAS); Rotations-Strategie kundenabhängig.

---

## Audit-Events (MVP) – Schema & Retention

- Speicherung: SQLite Tabelle `audit_events`.
- Pflichtfelder:
  - `id` (INTEGER PRIMARY KEY AUTOINCREMENT)
  - `ts` (DATETIME, UTC)
  - `actor_user_id` (TEXT, nullable für anonyme/fehlgeschlagene Versuche)
  - `actor_role` (TEXT)
  - `ip` (TEXT)
  - `action` (TEXT; z. B. `user.create`, `user.update`, `role.assign`, `auth.login`, `access_denied`)
  - `target_type` (TEXT; z. B. `user`, `role`, `system`)
  - `target_id` (TEXT, optional)
  - `status` (TEXT; `success`|`failed`|`denied`)
  - `before` (JSON, optional; sensible Felder gehasht/ausgeblendet)
  - `after` (JSON, optional; sensible Felder gehasht/ausgeblendet)
  - `correlation_id` (TEXT)
- Retention/Archivierung:
  - Lokal 30 Tage in SQLite, dann Export/Archiv nach MinIO Bucket `audit/archive/` (JSONL). Konfigurierbar (7–90 Tage).
  - Kompression optional (gzip). Löschung lokaler Alt-Datensätze nach erfolgreichem Export.
- Datenschutz:
  - Keine Klartext-Passwörter/TOTP-Secrets; nur Hash-/Maskierung. Minimierung personenbezogener Inhalte.
