# Jetson Admin (E1.1)

Diese App liefert Benutzer- & Rollenverwaltung (RBAC), optional 2FA (TOTP), Audit-Logging und eine minimale Admin-UI.

## Schnellstart

1. .env prüfen: `DATABASE_URL="file:./dev.db"`, `SESSION_SECRET` setzen
2. Migrationen anwenden: `npm run prisma:migrate`
3. Seed laden: `npm run seed`
4. Entwicklung starten: `npm run dev` (http://localhost:3000)
   - Admin-UI: `http://localhost:3000/admin` (Login `admin@example.com` / `admin123`)

## API-Auszug

- Auth: `POST /auth/login { email,password, totp? }`, `POST /auth/logout`
- 2FA: `POST /auth/enable-2fa`, `POST /auth/reset-password`
- Benutzer: `GET/POST /users`, `PUT/DELETE /users/:id`, `POST /users/:id/roles`
- Rollen: `GET/POST /roles`, `PUT/DELETE /roles/:id`

## Admin-UI

- Login: `/admin/login`
- Dashboard: `/admin`
- Benutzerliste/Anlage: `/admin/users`
- Rollenliste/Anlage: `/admin/roles`

## RBAC

- Session-basierte Authentifizierung mit Rollenauflösung aus DB
- Middleware `requireRoles(["admin"])` für API-Routen
- UI-Guards `requireUiAuth` und `requireUiRole("admin")`

## 2FA (TOTP)

- Optional je Benutzer aktivierbar: `POST /auth/enable-2fa` (liefert Secret)
- Bei aktivem 2FA ist beim Login ein TOTP erforderlich

## Audit-Logging

- `AuditEvent` zeichnet Wer/Was/Wann mit Before/After auf
- Aktionen: Login/Logout, User/Rollen Create/Update/Deactivate, Rollen-Zuweisung

## Security-Hinweise

- `helmet` aktiviert, CORS ist permissiv für lokale Entwicklung (Credentials aktiv)
- Setze `SESSION_SECRET` und aktiviere `cookie.secure` hinter TLS
- Produktionsbetrieb: TLS-Termination, HSTS, sichere Cookies, Rate-Limiting, CSRF für Formular-POSTs (optional)

## Tests

- Jest/Supertest: `npm test`
- Deckt Health, RBAC, Benutzer-/Rollen-CRUD und Login ab

