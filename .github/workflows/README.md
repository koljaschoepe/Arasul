# GitHub Actions Workflows

## Übersicht

Diese CI/CD-Pipelines automatisieren Tests, Security-Audits und Deployments für das Arasul-Projekt.

**Story:** E1.2 (Automated Integration Tests)

## Workflows

### 1. CI/CD Pipeline (`ci.yml`)

**Trigger:** Push/PR auf `main` oder `develop`

**Jobs:**
- **Lint & Type Check**: TypeScript-Kompilierung und Linting
- **Unit Tests**: Jest-Tests mit Coverage-Report
- **Security-Header Tests**: E1.2-spezifische Tests
- **Docker Integration Tests**: Full-Stack-Tests mit Docker Compose
- **TLS Validation**: TLS/Security-Header-Validierung mit testssl.sh
- **Build Summary**: Aggregierte Ergebnisse

**Laufzeit:** ~8-10 Minuten

**Erfolg-Kriterien:**
- ✅ Alle Unit-Tests erfolgreich
- ✅ TypeScript-Build fehlerfrei
- ✅ Security-Header vorhanden
- ✅ Docker-Container starten erfolgreich

### 2. Security Audit (`security-audit.yml`)

**Trigger:** 
- Täglich um 3:00 UTC (Cron)
- Manuell (workflow_dispatch)
- Push auf `main`

**Jobs:**
- **Dependency Audit**: NPM-Packages auf Vulnerabilities prüfen
- **Container Scan**: Docker-Image-Scan mit Trivy
- **Security-Header Compliance**: Header-Validierung
- **Cert Expiry Check**: Zertifikatsablauf-Warnung (<30 Tage)

**Laufzeit:** ~5-7 Minuten

**Erfolg-Kriterien:**
- ✅ Keine kritischen/hohen Vulnerabilities
- ✅ Alle Security-Header vorhanden
- ✅ Zertifikat noch >30 Tage gültig

## Setup

### 1. GitHub Secrets konfigurieren

Erforderliche Secrets:
```bash
# In GitHub: Settings → Secrets → Actions

SESSION_SECRET=<production-secret>
SMTP_PASSWORD=<email-notification-password>
SLACK_WEBHOOK=<optional-slack-webhook-url>
```

### 2. Branch Protection aktivieren

```bash
# In GitHub: Settings → Branches → Add rule

Branch name pattern: main
☑ Require status checks to pass
  ☑ ci / lint
  ☑ ci / test
  ☑ ci / security-tests
  ☑ ci / integration-tests
  ☑ ci / tls-validation
☑ Require branches to be up to date
☑ Require code review (1 approver)
```

### 3. Code Owners aktivieren

Die `.github/CODEOWNERS` Datei definiert automatische Reviewer:
- Security-kritische Dateien → `@security-team`
- Infrastructure → `@devops-team`
- Backend-Code → `@backend-team`
- Tests → `@qa-team`

## Lokales Testen der CI/CD

### Mit Act (GitHub Actions Emulator)

```bash
# Act installieren
brew install act  # macOS
# oder: https://github.com/nektos/act

# CI-Workflow lokal ausführen
act push

# Spezifischen Job ausführen
act -j test

# Mit Secrets
act --secret-file .secrets
```

### Manuelles Testen

```bash
# Alle Tests wie in CI ausführen
cd app
npm ci
npm test -- --coverage
npm run build

# Docker-Build
docker build -t arasul-api:local -f Dockerfile .

# Integration-Tests
docker-compose up -d
curl http://localhost:3000/health
docker-compose down -v
```

## Monitoring

### GitHub Actions Dashboard

- **Status-Badge:** 
  ```markdown
  ![CI](https://github.com/arasul/jetson/actions/workflows/ci.yml/badge.svg)
  ```

- **Workflow-Runs:** `Actions` Tab in GitHub

- **Test-Coverage:** Codecov-Integration (optional)

### Notifications

**Email-Benachrichtigungen:**
- GitHub sendet automatisch Emails bei fehlgeschlagenen Workflows

**Slack-Integration (optional):**
```yaml
# In ci.yml erweitern
- name: Notify Slack
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: failure
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## Troubleshooting

### Problem: Job schlägt fehl mit "Network error"

**Lösung:**
```bash
# In docker-compose.ci.yml Network-Mode anpassen
services:
  api:
    network_mode: "host"
```

### Problem: "testssl.sh: command not found"

**Lösung:**
```yaml
# testssl.sh wird im Workflow installiert
- name: Install testssl.sh
  run: |
    git clone --depth 1 https://github.com/drwetter/testssl.sh.git
```

### Problem: Tests hängen bei "Wait for API"

**Lösung:**
```bash
# Timeout erhöhen oder Health-Check anpassen
timeout 120 bash -c 'until curl -sf http://localhost:3000/health; do sleep 2; done'
```

### Problem: Coverage-Report wird nicht hochgeladen

**Lösung:**
```bash
# Codecov-Token als Secret hinzufügen
# Settings → Secrets → CODECOV_TOKEN
```

## Performance-Optimierung

### Caching aktivieren

```yaml
# node_modules cachen (bereits aktiv)
- uses: actions/setup-node@v4
  with:
    cache: 'npm'
```

### Parallele Jobs

Jobs ohne Dependencies laufen parallel:
- `lint` + `test` + `security-tests` (parallel)
- `integration-tests` (nach erfolgreichen Unit-Tests)
- `tls-validation` (nach Integration-Tests)

### Self-Hosted Runner (optional)

Für schnellere Builds mit eigenem Hardware:
```yaml
runs-on: self-hosted
```

## Best Practices

1. **Fail Fast:** Kritische Tests zuerst (Lint, Build)
2. **Isolierte Jobs:** Jeder Job startet mit sauberem State
3. **Artifact Upload:** Test-Reports und Coverage für Debugging
4. **Timeout:** Alle Jobs haben Timeout (max. 30 min)
5. **Cleanup:** `if: always()` für Docker-Cleanup

## Security-Hinweise

- ⚠️ **Secrets niemals in Logs ausgeben**
- ✅ `actions/checkout@v4` verwendet (sichere Version)
- ✅ Docker-Images werden nicht gepusht (nur lokal gebaut)
- ✅ NPM-Pakete mit `npm ci` (lockfile-basiert)

## Weitere Ressourcen

- [GitHub Actions Dokumentation](https://docs.github.com/en/actions)
- [Act (Lokales Testing)](https://github.com/nektos/act)
- [Trivy Scanner](https://github.com/aquasecurity/trivy)
- [testssl.sh](https://github.com/drwetter/testssl.sh)

---

**Version:** 1.0  
**Story:** E1.2 (CI/CD Integration)  
**Autor:** Dev Agent (Claude Sonnet 4.5)  
**Datum:** 2025-10-14

