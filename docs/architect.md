# Arasul – Systemarchitektur (v0.3)

Version: 0.3  
Datum: 14. Oktober 2025  
Quelle: jetson/docs/PRD.md (Arasul PRD v2.2)

---

## 1. Architekturübersicht

Ziel ist eine vollständig lokal betriebene Edge-Plattform auf NVIDIA Jetson-Geräten. Zugriff erfolgt ausschließlich über WireGuard-VPN; sämtliche Dienste werden per Caddy als Reverse-Proxy unter HTTPS bereitgestellt. Die Managementoberfläche ist ein Dashboard (Web-App) mit Live-Metriken, Service-Shortcuts und Administrationsfunktionen.

High-Level-Komponenten:
- WireGuard (VPN, Port 51820/UDP) mit dediziertem /24-Subnetz pro Gerät/Kunde
- Caddy (TLS-Terminierung, Reverse-Proxy, Security-Headers)
- Dashboard Web-App (React/Tailwind/Shadcn) + Backend-API (Node.js oder FastAPI)
- Services: n8n, MinIO, Guacamole, Monitoring-API (Docker Compose)
- Persistenz: SQLite (WAL-Mode) für Auth, Sessions, Audit; Backups via Dateikopie/MinIO-Sync

---

## 2. Laufzeit-Topologie

Alle Komponenten laufen containerisiert (Docker Compose) auf dem Jetson. Caddy exponiert Subpfade:
- `/` → Dashboard
- `/api` → Backend-API
- `/n8n` → n8n
- `/minio` → MinIO Console/S3 Endpunkte
- `/guacamole` → Apache Guacamole
- `/monitor` → Monitoring-/Logs-UI

Netzfluss (vereinfacht):
1. Client verbindet WireGuard → erhält IP im 10.80.x.0/24.
2. Zugriff via `https://10.80.x.x/…` → Caddy terminiert TLS und routet intern per Subpfad.
3. Dashboard-Frontend spricht Backend-API und WebSocket-Endpunkte für Live-Metriken.

---

## 3. Security-Architektur (MVP)

- Auth: lokale Benutzerverwaltung (SQLite), Rollen: `admin`, `user`, `vendor_readonly`.
- Passwörter: Argon2id; Passwort-Policy (Mindestlänge 12, Zxcvbn ≥ 3, Blacklist).
- 2FA: TOTP optional je Benutzer; Backup-Codes.
- Sessions: `Secure`, `HttpOnly`, `SameSite=Strict`, Idle-Timeout 15 min, Absolute-Timeout 8 h.
- Rate-Limit & Lockout: 5 Fehlversuche/10 min → Lock 10 min; IP-Backoff.
- Audit-Logging: Security-Events, Admin-Aktionen, Service-Launches.
- TLS: Caddy, bevorzugt TLS 1.3; self-signed (MVP), step-ca vorbereitet (Phase 1.5); HSTS/CSP/XFO/CTO etc.
- Caddy erzeugt automatisch ein self-signed Zertifikat (z. B. `arasul.local`); Zertifikatsrotation via Caddy Auto-Renew.
- CSP: `frame-src 'self'` für Guacamole-Einbettung (Iframe); weitere Direktiven gemäß Härtungsleitfaden.

SSO (Phase 1.5): OIDC via Authentik über ForwardAuth; Rollen-Mapping per Claims.

---

## 4. Dashboard-First UX

- Landing `/dashboard`: Live-Metriken (CPU/GPU/RAM/Disk/Net, ~2s Interval), Service-Kacheln (n8n/MinIO/Guacamole/Monitoring), Systeminfo (Hostname, Uptime, WireGuard-IP), Admin-Aktionen (Restart Services, Update, Reboot, Terminal öffnen/Guacamole).
- Guacamole-Integration: Standardmäßig Iframe im Dashboard; optionaler Button „In neuem Tab öffnen“ für Admins. Iframe-URL: `/guacamole/#/client/<conn-id>?embed=true`.
- UI: Tailwind, dunkles Standard-Theme, responsive.

---

## 5. API-Schnittstellen (Auszug)

- `POST /api/auth/login`, `POST /api/auth/logout`, `GET /api/me`
- `GET /api/system/stats` → CPU/GPU/RAM/Disk/Net/Temps
- `GET /api/services` → Service-Status (healthy/unhealthy)
- `POST /api/admin/service/{name}/{restart|start|stop}` (admin)
- `POST /api/admin/system/{reboot|update}` (admin)
- `GET /api/audit?limit=…`

---

## 6. Deployment & Updates

- Basis-Image: Ubuntu 22.04 L4T, Docker + Compose, WireGuard, Caddy, Dashboard+API, n8n, MinIO, Guacamole, Monitoring.
- Provisionierung: SD/SSD-Image oder USB-Installer (Cloud-Init). First-Boot-Wizard: Hostname, Admin-Konto, WireGuard-Config (QR).
- Updates: `docker compose pull && docker compose up -d`; OS via `apt` oder Dashboard-Action „Update System“.
- Keine Cloud-Komponenten; alles lokal im Kundennetz.

---

## 7. Monitoring & Observability

- Systemmetriken via Node-Exporter/Custom-API, WebSocket-Streaming (≈2s).
- Service-Health per Docker API (healthcheck).
- Logging/Artefakte: MinIO Buckets (`/logs/`, `/audit/`). Retention: Standard 30 Tage lokal; nach 30 Tagen automatische Löschung oder Kompression nach `/data/archive/`. Optionaler Export nach MinIO Bucket `logs/archive/`. Retention im Dashboard konfigurierbar (7–90 Tage).

---

## 8. Datenpersistenz

- Auth/Sessions/Audit: SQLite (MVP) auf Device mit `PRAGMA journal_mode=WAL;`. Für den MVP keine PostgreSQL-Instanz. Backups per konsistenter Dateikopie (WAL beachten) oder MinIO-Sync.
- Audit-Daten: 30 Tage lokal in SQLite; ältere Einträge werden in MinIO archiviert.
- MinIO: Objektspeicher lokal; S3-kompatible Endpunkte via Caddy.
- Backups: lokal exportierbar (USB/NAS); Rotations-Strategie kundenabhängig.

---

## 9. Storage & Backups (MinIO)

- Benutzerkonzept (MVP): Single-Admin-User (kein Endnutzer-/Multi-User-Management im MVP).
- Credentials: `MINIO_ROOT_USER` und `MINIO_ROOT_PASSWORD` aus Dashboard-Secret-Store verwaltet.
- Nutzung: System-/Service-Backups und Log-/Audit-Archivierung; kein öffentlicher Direktzugriff.
- Erreichbarkeit: nur intern über Reverse-Proxy-Subpfad `/minio`; Zugriff vorzugsweise via Dashboard-Link.
- Future-Plan: Multi-User & Bucket-Policies (Phase 2) inkl. RBAC-Sync mit Dashboard.

---

## 10. Netz & Ports (Default)

- WireGuard: 51820/UDP (eingehend, VPN only)
- HTTPS (Caddy): 443/TCP (nur im VPN/LAN)
- HTTP (Caddy): 80/TCP (nur im VPN) → 301 Redirect auf 443/TCP
- Interne Container-Ports: nicht extern exponiert; nur via Reverse-Proxy erreichbar

---

## 11. Threat Model (Kurzfassung)

Angriffsflächen: VPN-Key-Diebstahl, schwache Passwörter, CSRF/XSS im Dashboard, verwaiste Sessions, überprivilegierte Accounts.  
Mitigation: Argon2id, TOTP, Least-Privilege RBAC, Security-Headers (CSP, HSTS), CSRF-Tokens, kurze Session-Timeouts, Audit-Logs, Key-Rotation.

---

## 12. Offene Punkte & Annahmen

Annahmen:
- SSO ist nicht Teil des MVP; OIDC via Authentik wird als Phase 1.5 nachgerüstet.
- Board- und JetPack-spezifische Optimierungen erfolgen außerhalb des MVP-Kerns.
- Zugriff erfolgt ausschließlich über WireGuard; kein öffentlicher Reverse-Tunnel.

Offene Fragen: keine (MVP-Entscheidungen final).

---

## 13. Nächste Schritte

- Detaildesign für API und Datenmodell verfeinern (Schema, Endpunkte, Fehlercodes).
- Compose-Stacks versionieren (prod/dev Profile), Healthchecks definieren.
- Security-Härtung in Caddy (TLS 1.3, CSP inkl. `frame-src 'self'`, ForwardAuth-Hooks) konkretisieren.

---

## 14. Entscheidungen & Change-Log (MVP)

- Datenbank: SQLite (MVP) mit WAL; Backups via Dateikopie/MinIO; PostgreSQL erst ab Phase 2 (Fleet/Multi-Device).
- TLS: self-signed (MVP) über Caddy; step-ca als Phase 1.5 vorbereitet; Rotation via Caddy Auto-Renew.
- Guacamole: Einbettung per Iframe im Dashboard; optionaler „Neuer Tab“-Button; CSP angepasst (`frame-src 'self'`).
- MinIO: Single-Admin-User; Secrets via Dashboard; kein externes Benutzer-Management im MVP.
- Logging & Audit: 30 Tage Retention; Auto-Löschung/Kompression nach `/data/archive/`; optionaler Export nach `logs/archive/` in MinIO; Dashboard-Konfiguration 7–90 Tage.
 - Healthcheck-Policy: Docker `healthcheck` mit `interval=30s`, `timeout=5s`, `retries=3`, `start_period=30s` für zentrale Services (Caddy, API, n8n, MinIO, Guacamole).
 - WebSocket-Limitierung: Update-Intervall standard 2s; pro Client maximal 1 Request/2s (serverseitiges Rate-Limit), Backoff bei Last.


