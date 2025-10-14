# Shard 09: Storage & Backups (MinIO)

- Benutzerkonzept (MVP): Single-Admin-User (kein Endnutzer-/Multi-User-Management im MVP).
- Credentials: `MINIO_ROOT_USER` und `MINIO_ROOT_PASSWORD` aus Dashboard-Secret-Store verwaltet.
- Nutzung: System-/Service-Backups und Log-/Audit-Archivierung; kein öffentlicher Direktzugriff.
- Erreichbarkeit: nur intern über Reverse-Proxy-Subpfad `/minio`; Zugriff vorzugsweise via Dashboard-Link.
- Future-Plan: Multi-User & Bucket-Policies (Phase 2) inkl. RBAC-Sync mit Dashboard.
