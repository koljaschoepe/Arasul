# Shard 02: Laufzeit-Topologie

Alle Komponenten laufen containerisiert (Docker Compose) auf dem Jetson. Caddy exponiert Subpfade:
- `/` → Dashboard
- `/api` → Backend-API
- `/n8n` → n8n
- `/minio` → MinIO Console/S3 Endpunkte
- `/guacamole` → Apache Guacamole
- `/monitor` → Monitoring-/Logs-UI

Netzfluss (vereinfacht):
1. Client verbindet WireGuard → erhält IP im 10.80.x.0/24.
2. Zugriff via `https://10.80.x.x/…` → Caddy terminiert TLS und routet intern per Subpfad.
3. Dashboard-Frontend spricht Backend-API und WebSocket-Endpunkte für Live-Metriken.
