# 12. Funktionale Requirements (FRs)

Die folgenden FRs konsolidieren die im PRD beschriebenen MVP-Funktionen. Jede Anforderung besitzt prüfbare Akzeptanzkriterien.

## FR-AUTH-001 – Lokale Authentifizierung & RBAC (MVP)
- Benutzerverwaltung lokal (SQLite im MVP), Rollen: `admin`, `user`, `vendor_readonly`
- Passwort-Hashing Argon2id, optionale TOTP-2FA, sichere Cookies/Sessions
- Rate-Limit, Lockout und Audit-Events

Akzeptanzkriterien:
- Login/Logout, Session-Timeouts, Lockout und TOTP funktionieren gemäß Abschnitt „Security & Auth“
- Audit-Events werden für Login/Logout/Rollenänderungen erfasst

## FR-TLS-001 – HTTPS/TLS & Reverse Proxy
- Caddy terminiert TLS (lokale CA/step-ca), Strict Security Headers, HTTP→HTTPS Redirect
- Interne Services hinter Reverse-Proxy/Subpfaden

Akzeptanzkriterien:
- SSL Labs A+; HSTS/CSP/XFO/Referrer-Policy gemäß Spezifikation gesetzt

## FR-VPN-001 – WireGuard-only Zugriff
- Zugriff ausschließlich über WireGuard-VPN-Subnetz

Akzeptanzkriterien:
- Dienste nur über VPN-IP erreichbar; keine Public-Exposition

## FR-DASH-001 – Dashboard Monitoring (Live)
- Live-Metriken (CPU, GPU, RAM, Disk, Net), Service-Kacheln, Systeminfo, Admin-Aktionen

Akzeptanzkriterien:
- Live-Update ≤ 2s, Ladezeit ≤ 3s, responsive UI

## FR-SVC-001 – Service-Management
- Start/Stop/Restart pro Service, Status (healthy/unhealthy), Log-Ansicht

Akzeptanzkriterien:
- 100% erfolgreicher Restart in Tests; Logs abrufbar

## FR-API-001 – Management- und Monitoring-APIs
- Auth-Endpoints, `GET /api/system/stats`, `GET /api/services`, Admin-Actions

Akzeptanzkriterien:
- Endpoints liefern definierte Schemas; RBAC greift

## FR-GUAC-001 – Guacamole-Integration (Konsole)
- Erreichbar nur hinter Dashboard-Session (Subpfad `/guacamole`)

Akzeptanzkriterien:
- Kein Direktzugang ohne Dashboard-Session

## FR-N8N-001 – n8n-Automation
- Bereitstellung als Container, Subpfad `/n8n`, Templates (Health, Backup, Logs, Mail)

Akzeptanzkriterien:
- Templates laufen fehlerfrei; Persistenz nach Neustart

## FR-MINIO-001 – MinIO S3-Storage
- Buckets (system-logs, backups, datasets, audit, user-data), Policies, Monitoring

Akzeptanzkriterien:
- S3-API kompatibel; Upload/Download-Performance gemäß Zielwerten

## FR-SETUP-001 – First-Boot-Wizard & Provisioning
- Auto-Detection (Board/JetPack), `.env`-Generierung, Onboarding-Wizard (einmalig)

Akzeptanzkriterien:
- Setup ≤ 15 Minuten; `.env` korrekt generiert; Wizard durchläuft fehlerfrei

## FR-ADMIN-001 – Systemaktionen
- Reboot, Update, Backup, Log-Export; nur für `admin`

Akzeptanzkriterien:
- Aktionen auditierbar und rollenbeschränkt

## FR-ALERT-001 – Alarme & Benachrichtigungen
- Alerts für hohe Last, Disk-Füllstände, Service-Crash, Failed-Logins; In-App + optional E-Mail/Webhook

Akzeptanzkriterien:
- Benachrichtigung innerhalb definierter Latenzen; Quittierung sichtbar

## FR-SSO-001 – Authentik SSO (Phase 1.5, optional)
- OIDC-Integration, Gruppen→Rollen-Mapping, 2FA, Session-Policies

Akzeptanzkriterien:
- SSO-Login produktiv einsetzbar; RBAC via Claims wirksam

Hinweis: Die Legacy-Detail-Abschnitte (z. B. „MVP Features“) bleiben zur Tiefe bestehen. Diese FR-Liste ist die maßgebliche Übersicht.
