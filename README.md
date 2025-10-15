# Arasul - Edge Computing Management Platform

Arasul ist eine Edge-Computing-Managementplattform für Jetson Nano, entwickelt als MVP mit Fokus auf Security, Automation und Remote-Management.

## Quick Start

### Voraussetzungen
- Docker & Docker Compose
- Node.js 20+ (für Entwicklung)
- Bash (für Verifikationsskripte)

### Installation

```bash
# Repository klonen
cd /path/to/jetson

# Dependencies installieren
cd app && npm install

# Build & Start
cd ..
docker-compose up -d --build

# Health-Check
curl -k https://arasul.local/health
```

### Verifikation

```bash
# TLS & Security-Header testen
./scripts/verify-tls.sh

# SSL Labs Test
./scripts/ssl-labs-test.sh

# Unit-Tests
cd app && npm test
```

## Architektur

```
Client (VPN)
    ↓
Caddy (TLS-Terminierung, Port 443)
    ↓
┌──────────────────────────────────────┐
│         Docker-Netzwerk              │
│                                      │
│  ┌─────────────┐  ┌──────────────┐  │
│  │   Backend   │  │   n8n        │  │ [TODO: E2.x]
│  │   (Express) │  │   (Auto.)    │  │
│  └─────────────┘  └──────────────┘  │
│                                      │
│  ┌─────────────┐  ┌──────────────┐  │
│  │   MinIO     │  │  Guacamole   │  │ [TODO: E3.x/E4.x]
│  │   (Storage) │  │  (Remote)    │  │
│  └─────────────┘  └──────────────┘  │
└──────────────────────────────────────┘
```

## Projekt-Struktur

```
jetson/
├── app/                    # Backend (Express + Prisma)
│   ├── src/
│   │   ├── __tests__/      # Unit-Tests
│   │   ├── middlewares/    # RBAC, Session-Timeout, CSRF
│   │   ├── routes/         # API-Routen
│   │   ├── services/       # Auth, Audit
│   │   └── server.ts       # Express-Server
│   ├── prisma/             # Datenbank-Schema & Migrationen
│   └── Dockerfile
│
├── caddy/                  # TLS & Reverse-Proxy
│   ├── Caddyfile
│   └── README.md
│
├── docs/                   # Dokumentation
│   ├── architect.sharded/  # System-Architektur
│   ├── prd.sharded/        # Product Requirements
│   └── deployment/         # Deployment-Guides
│       └── tls-setup.md
│
├── scripts/                # Utility-Skripte
│   ├── verify-tls.sh
│   ├── ssl-labs-test.sh
│   └── export-ca-cert.sh
│
└── docker-compose.yml
```

## Features (MVP - Epic E1)

### ✅ E1.1: Auth, RBAC & CRUD (Completed)
- Authentifizierung (Session-basiert)
- Rollen-basierte Zugriffskontrolle (RBAC)
- User-Management (CRUD)
- Audit-Logging
- Session-Timeout (15 min Idle)
- Rate-Limiting
- CSRF-Schutz

### ✅ E1.2: TLS & Security-Header A+ (Completed)
- TLS 1.3 Terminierung via Caddy
- Self-signed Zertifikate (MVP)
- HTTP→HTTPS Redirect
- Security-Header (HSTS, CSP, XFO, etc.)
- Reverse-Proxy für alle Services
- SSL Labs A-Rating

### 🚧 E1.3: WireGuard VPN (Planned)
- VPN-only Zugriff
- Firewall-Konfiguration (iptables)

## Testing

### Unit-Tests
```bash
cd app

# Alle Tests
npm test

# Spezifische Story
npm test -- e11_validations.test.ts
npm test -- e12_tls_security_headers.test.ts

# Mit Coverage
npm run test:coverage
```

**Test-Status:** ✅ 28/28 Tests erfolgreich

### Manual Testing

```bash
# TLS-Verifikation
./scripts/verify-tls.sh arasul.local

# SSL Labs Test (lokal)
./scripts/ssl-labs-test.sh arasul.local

# CA-Zertifikat exportieren
./scripts/export-ca-cert.sh
```

## Deployment

### Entwicklung (lokal)

```bash
# Backend im Dev-Modus
cd app
npm run dev

# In separatem Terminal: Caddy
docker-compose up caddy
```

### Produktion

```bash
# Umgebungsvariablen konfigurieren
cp .env.example .env
nano .env  # SESSION_SECRET ändern!

# Services starten
docker-compose up -d --build

# Logs prüfen
docker-compose logs -f
```

### DNS-Konfiguration (lokal)

```bash
# /etc/hosts (Linux/macOS)
echo "127.0.0.1 arasul.local" | sudo tee -a /etc/hosts

# C:\Windows\System32\drivers\etc\hosts (Windows)
127.0.0.1 arasul.local
```

## Security

### Transport-Layer (Caddy)
- TLS 1.3 bevorzugt, TLS 1.2 als Fallback
- HSTS mit `max-age=31536000; includeSubDomains`
- Server-Header entfernt

### Content-Layer (Helmet)
- CSP mit `frame-src 'self'` für Guacamole-Iframe
- X-Frame-Options: `SAMEORIGIN`
- X-Content-Type-Options: `nosniff`
- Referrer-Policy: `strict-origin-when-cross-origin`
- X-Powered-By entfernt

### Application-Layer (Express)
- Session-Cookies: `httpOnly`, `secure` (Produktion), `sameSite=strict`
- CSRF-Schutz via Double Submit Cookie
- Rate-Limiting (Auth: 5/10min, API: 100/15min)
- Session-Timeout: 15 min Idle

### Infrastructure-Layer
- Docker-Netzwerk-Isolation
- Non-root Container-User
- VPN-only Zugriff (E1.3)

## Troubleshooting

### Browser zeigt "Unsichere Verbindung"

**Ursache:** Self-signed Zertifikat nicht vertraut  
**Lösung:**
```bash
# CA-Zertifikat exportieren
./scripts/export-ca-cert.sh

# Anleitung folgen (plattform-spezifisch)
# macOS: sudo security add-trusted-cert ...
# Linux: sudo cp ... /usr/local/share/ca-certificates/
# Windows: Doppelklick → "Zertifikat installieren"

# Browser neu starten
```

### Backend nicht erreichbar

**Prüfung:**
```bash
# Container-Status
docker-compose ps

# Backend direkt testen
docker exec api wget -O- http://localhost:3000/health

# Logs prüfen
docker-compose logs api
docker-compose logs caddy
```

### CSRF-Token-Fehler

**Prüfung:**
```bash
# Cookie-Header prüfen
curl -I -k https://arasul.local/auth/login | grep -i set-cookie
```

**Lösung:** Cache leeren, Browser neu starten

Weitere Troubleshooting-Hilfe: [docs/deployment/tls-setup.md](docs/deployment/tls-setup.md)

## Dokumentation

- **Architektur:** [docs/architect.sharded/](docs/architect.sharded/)
- **PRD:** [docs/prd.sharded/](docs/prd.sharded/)
- **TLS-Setup:** [docs/deployment/tls-setup.md](docs/deployment/tls-setup.md)
- **Caddy-Config:** [caddy/README.md](caddy/README.md)
- **Story-Reviews:**
  - [E1.1 Review](docs/prd.sharded/epics/E1/E1.1_review/)
  - [E1.2 Review](docs/prd.sharded/epics/E1/E1.2_review/)

## Development

### Technologie-Stack

**Backend:**
- Node.js 20 + TypeScript
- Express.js (REST API)
- Prisma (ORM)
- SQLite (MVP) / PostgreSQL (Produktion)
- Helmet (Security-Header)
- express-session (Session-Management)
- csrf-csrf (CSRF-Schutz)

**Infrastructure:**
- Docker & Docker Compose
- Caddy 2 (Reverse-Proxy & TLS)
- WireGuard VPN (E1.3)

**Testing:**
- Jest + Supertest
- ts-jest
- Test Coverage: ≥80%

### Code-Qualität

```bash
# TypeScript kompilieren
npm run build

# Linter (falls konfiguriert)
npm run lint

# Tests mit Coverage
npm run test:coverage
```

## Roadmap

### Phase 1: Foundation (MVP) [In Progress]
- ✅ E1.1: Auth, RBAC & CRUD
- ✅ E1.2: TLS & Security-Header A+
- 🚧 E1.3: WireGuard VPN

### Phase 2: Automation [Planned]
- E2.1: n8n Integration
- E2.2: Workflow-Bibliothek
- E2.3: Event-Triggers

### Phase 3: Storage & Backup [Planned]
- E3.1: MinIO Integration
- E3.2: Snapshot-Management
- E3.3: Backup-Automation

### Phase 4: Remote Desktop [Planned]
- E4.1: Apache Guacamole Integration
- E4.2: Terminal-Access

### Phase 1.5: PKI Enhancement [Future]
- step-ca Migration (lokale CA)
- Automatische Zertifikatsrotation

## Contributing

### Branch-Strategie
- `main` - Produktions-ready Code
- `dev` - Development Branch
- `feature/e1.x` - Feature Branches (per Story)

### Testing-Standards
- Alle neuen Features benötigen Unit-Tests
- Mindest-Coverage: 80%
- Keine Regressionstests fehlschlagen

### Commit-Messages
```
[E1.2] Add Caddy TLS configuration

- Implement TLS 1.3 termination
- Add security headers (HSTS, CSP)
- Configure reverse proxy routing
```

## License

*[TBD]*

## Support

- **Dokumentation:** [docs/](docs/)
- **Issues:** *[TBD]*
- **Architecture Questions:** Siehe [docs/architect.sharded/](docs/architect.sharded/)

---

**Version:** MVP (Epic E1.1 + E1.2)  
**Last Updated:** 2025-10-14  
**Status:** ✅ Ready for QA

