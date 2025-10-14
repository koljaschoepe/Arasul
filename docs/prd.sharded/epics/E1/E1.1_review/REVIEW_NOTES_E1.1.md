# Review Notes – Story E1.1 (User & Rollenverwaltung)

Bereit für Review.

## Umsetzung
- Tech: Express (TS, ESM), Prisma (SQLite Dev), EJS UI, Jest/Supertest
- Domain: User, Role, UserRole, AuditEvent; RBAC, optional 2FA (TOTP), Audit-Logging
- Admin-UI unter `/admin` (Login: admin@example.com / admin123)

## Tests
- 8 grüne Tests (CRUD, RBAC 403, 2FA-Flow, Audit-Events)
- Tests isolieren 2FA-Zustand; Unique-Kollisionen vermieden

## Sicherheit
- helmet aktiv, Sessions; für Prod: TLS/HSTS, secure Cookies, Rate-Limits, CSRF für Form-POSTs empfohlen

## Hinweise für Reviewer
- Checke AuditEvent-Einträge bei User/Role Änderungen
- Probiere 2FA aktivieren → TOTP-Login → wieder deaktivieren
- RBAC: Non-Admin darf `/users` nicht lesen (403)

## Offene Verbesserungen (Folge-PRs)
- CSRF-Token in Admin-Forms
- Granularere Permissions jenseits reiner Rollen
- Pagination/Filter/Sortierung in UI-Listen
