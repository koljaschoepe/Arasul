# Arasul PRD – Übersicht (Shard 00)

**Version:** 2.3  
**Datum:** 14. Oktober 2025  
**Status:** MVP Phase  
**Priorisierung:** Business Value

---

## Executive Summary
Arasul ist eine lokal betriebene Open-Source Edge-Plattform für NVIDIA Jetson-Geräte. Zugriff ausschließlich via WireGuard-VPN; TLS via Caddy; Dashboard-first UX mit Systemmetriken und integrierten Services (n8n, MinIO, Guacamole). Keine Cloud-Abhängigkeit, kein Reverse-Tunnel im MVP.

- Plug-&-Play Setup ≤ 15 Minuten
- 100% lokale Datenverarbeitung (Zero-Trust, VPN-only)
- HTTPS via Caddy (lokale CA/step-ca)
- Integrierte Automatisierung, Dashboard-first UX
- Zero Vendor Lock-in

---

## System-Architektur (Kurzüberblick)
- Netzwerk: Eigener WireGuard-Server je Gerät, Zugriff nur via VPN-IP
- TLS/Proxy: Caddy terminiert TLS; Services hinter Subpfaden
- Application Layer: React/Tailwind/Shadcn Dashboard + API; Services als Docker-Container (n8n, MinIO, Guacamole)

---

## Security & Auth (MVP)
- Lokale User in SQLite (WAL), Rollen: admin, user, vendor_readonly
- Passwörter: Argon2id; optionale TOTP-2FA
- Sessions: Secure/HttpOnly/SameSite=Strict, Idle 30min, Absolute 8h
- Rate-Limit & Lockout; Audit-Events

---

## Dashboard-First UX (Kurz)
- Landing: /dashboard mit Live-Metriken (WS/2s)
- Service-Kacheln: /n8n, /minio, /guacamole, /monitor
- Admin-Actions: Restart Services, Update, Reboot, Terminal

---

## APIs (MVP Auszug)
- POST /api/auth/login|logout, GET /api/me
- GET /api/system/stats, GET /api/services
- POST /api/admin/service/{name}/(restart|start|stop)
- POST /api/admin/system/(reboot|update)
- GET /api/audit?limit=…

---

## DoD (MVP) – Auszug
- Lokale Auth + RBAC + optionale TOTP
- Dashboard-First UX mit Systemlast + Service-Kacheln
- Dienste nur via VPN + HTTPS erreichbar
- Audit-Logging, Security-Headers, Rate-Limit

---

## Risiken (Auszug)
- VPN-Key-Management, Performance auf Nano, Disk-Full, Update-Risiken
- Mitigation: Rotation/Revocation UI, Optimierung, Quotas, Rollback/Signierung

---

## Technische Anhänge (Kurz)
- Ports: 51820/UDP (WG), 443/TCP (HTTPS), 80/TCP intern→Redirect
- Netz: 10.80.x.0/24 je Gerät
- Mermaid (High-Level): WG → Caddy → Dashboard → Services

---

Verweise: Details in Shards 12 (FRs), 13 (NFR-Übersicht), 14 (Epics & Stories).
