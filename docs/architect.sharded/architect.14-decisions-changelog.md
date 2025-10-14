# Shard 14: Entscheidungen & Change-Log (MVP)

- Datenbank: SQLite (MVP) mit WAL; Backups via Dateikopie/MinIO; PostgreSQL erst ab Phase 2 (Fleet/Multi-Device).
- TLS: self-signed (MVP) über Caddy; step-ca als Phase 1.5 vorbereitet; Rotation via Caddy Auto-Renew.
- Guacamole: Einbettung per Iframe im Dashboard; optionaler „Neuer Tab“-Button; CSP angepasst (`frame-src 'self'`).
- MinIO: Single-Admin-User; Secrets via Dashboard; kein externes Benutzer-Management im MVP.
- Logging & Audit: 30 Tage Retention; Auto-Löschung/Kompression nach `/data/archive/`; optionaler Export nach `logs/archive/` in MinIO; Dashboard-Konfiguration 7–90 Tage.
- Healthcheck-Policy: Docker `healthcheck` mit `interval=30s`, `timeout=5s`, `retries=3`, `start_period=30s` für zentrale Services (Caddy, API, n8n, MinIO, Guacamole).
- WebSocket-Limitierung: Update-Intervall standard 2s; pro Client maximal 1 Request/2s (serverseitiges Rate-Limit), Backoff bei Last.
