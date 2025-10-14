# 13. Non-Functional Requirements (NFRs) – Übersicht

Dies ist eine konsolidierte Übersicht. Detailwerte und vollständige Tabellen finden sich in Abschnitt „5. Non-Functional Requirements“.

- Performance: Boot ≤ 60s, Dashboard ≤ 3s, API p95 ≤ 200ms, MinIO ≥ 200 MB/s
- Reliability: Uptime ≥ 99.5%, Update-Success ≥ 98%, Data-Durability 99.999%
- Security: TLS 1.3, A+ Rating, 0 Critical/High CVEs, Lockout nach 5 Fehlversuchen
- Usability: Setup ≤ 15min, Task-Success ≥ 95%, Mobile-Responsive
- Maintainability: Coverage ≥ 80%, License-Compliance 100%, monatliche Container-Updates
- Portability: Jetson Nano/Orin/Thor, generisches ARM64, vollständiger Datenexport
