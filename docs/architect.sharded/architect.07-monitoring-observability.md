# Shard 07: Monitoring & Observability

- Systemmetriken via Node-Exporter/Custom-API, WebSocket-Streaming (≈2s).
- Service-Health per Docker API (healthcheck).
- Logging/Artefakte: MinIO Buckets (`/logs/`, `/audit/`). Retention: Standard 30 Tage lokal; nach 30 Tagen automatische Löschung oder Kompression nach `/data/archive/`. Optionaler Export nach MinIO Bucket `logs/archive/`. Retention im Dashboard konfigurierbar (7–90 Tage).
