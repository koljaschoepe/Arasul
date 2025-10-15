# Jetson Admin Backend (E1.1 + E1.2)

Diese App liefert Benutzer- & Rollenverwaltung (RBAC), optional 2FA (TOTP), Audit-Logging und eine minimale Admin-UI. In Produktion läuft sie hinter Caddy (TLS-Terminierung) im Docker-Container.

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

## Security (E1.1 + E1.2)

### Helmet Security-Header (E1.2)
- ✅ CSP mit `frame-src 'self'` für Guacamole-Iframe (E4.x)
- ✅ X-Frame-Options: `SAMEORIGIN`
- ✅ X-Content-Type-Options: `nosniff`
- ✅ Referrer-Policy: `strict-origin-when-cross-origin`
- ✅ X-Powered-By entfernt
- ⚠️ HSTS wird von Caddy gesetzt (Transport-Layer)

### Application Security (E1.1)
- ✅ Session-basierte Authentifizierung
- ✅ CSRF-Schutz (doubleCsrf für POST/PUT/DELETE)
- ✅ Rate-Limiting (Auth: 5/10min, API: 100/15min)
- ✅ Session-Timeout: 15 min Idle
- ✅ Session-Cookies: `httpOnly`, `secure` (Produktion), `sameSite=strict`

### Deployment Security
- Setze `SESSION_SECRET` in `.env` (KRITISCH!)
- `cookie.secure=true` automatisch in Produktion (NODE_ENV=production)
- TLS-Terminierung via Caddy (siehe `/jetson/caddy/`)
- Reverse-Proxy: Backend nicht direkt exponiert

## Tests

- Jest/Supertest: `npm test`
- Deckt Health, RBAC, Benutzer-/Rollen-CRUD und Login ab

