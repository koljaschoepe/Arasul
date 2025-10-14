# Arasul – Systemarchitektur (Shard 00: Übersicht)

Version: 0.3  
Datum: 14. Oktober 2025  
Quelle: `jetson/docs/architect.md`

---

## Architekturübersicht
Ziel ist eine vollständig lokal betriebene Edge-Plattform auf NVIDIA Jetson-Geräten. Zugriff erfolgt ausschließlich über WireGuard-VPN; sämtliche Dienste werden per Caddy als Reverse-Proxy unter HTTPS bereitgestellt. Die Managementoberfläche ist ein Dashboard (Web-App) mit Live-Metriken, Service-Shortcuts und Administrationsfunktionen.

High-Level-Komponenten:
- WireGuard (VPN, Port 51820/UDP) mit dediziertem /24-Subnetz pro Gerät/Kunde
- Caddy (TLS-Terminierung, Reverse-Proxy, Security-Headers)
- Dashboard Web-App (React/Tailwind/Shadcn) + Backend-API (Node.js oder FastAPI)
- Services: n8n, MinIO, Guacamole, Monitoring-API (Docker Compose)
- Persistenz: SQLite (WAL-Mode) für Auth, Sessions, Audit; Backups via Dateikopie/MinIO-Sync
