# Shard 03: Security-Architektur (MVP)

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

## RBAC Enforcement (MVP)

- Rollen: `admin`, `user`, `vendor_readonly`.
- Prinzip: Least Privilege; Default = deny.
- Enforcement-Ebenen:
  - Router-Guards pro Endpunkt (Middleware): prüft Authn, 2FA-Status (falls erzwungen), Rolle, ggf. Ressourcen-Kontext.
  - Handler-Guards (defense in depth): validiert nochmals kritische Aktionen.
- Entscheidungslogik (vereinfachte Matrix):
  - `admin`: Vollzugriff auf Admin-Endpunkte (`/api/admin/**`), inkl. Benutzer-/Rollen-CRUD, Service-/Systemaktionen.
  - `user`: Lesen von System-/Service-Infos; kein Zugriff auf Admin-Endpunkte.
  - `vendor_readonly`: Read-only auf Monitoring-/System-Status; kein Zugriff auf Admin- oder Mutations-Endpunkte.
- 403/401 Regeln:
  - 401 bei fehlender/ungültiger Session; 403 bei fehlender Berechtigung.
  - Jeder 403 wird als Audit-Event „access_denied" mit `actor`, `endpoint`, `method`, `ip`, `ts` geloggt (ohne sensitive Payloads).
- 2FA:
  - Optional pro Benutzer aktivierbar. Wenn Organisation 2FA erzwingt (Future Flag), ist Zugriff auf Admin-Endpunkte nur mit verifizierter 2FA-Session erlaubt.
- Rate-Limits:
  - Admin-Endpunkte enger limitiert (z. B. 20 req/min/IP), Auth-Endpunkte mit Backoff.
