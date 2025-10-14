# Shard 06: Deployment & Updates

- Basis-Image: Ubuntu 22.04 L4T, Docker + Compose, WireGuard, Caddy, Dashboard+API, n8n, MinIO, Guacamole, Monitoring.
- Provisionierung: SD/SSD-Image oder USB-Installer (Cloud-Init). First-Boot-Wizard: Hostname, Admin-Konto, WireGuard-Config (QR).
- Updates: `docker compose pull && docker compose up -d`; OS via `apt` oder Dashboard-Action „Update System“.
- Keine Cloud-Komponenten; alles lokal im Kundennetz.
