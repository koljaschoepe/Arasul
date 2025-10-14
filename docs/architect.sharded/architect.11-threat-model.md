# Shard 11: Threat Model (Kurzfassung)

Angriffsflächen:
- VPN-Key-Diebstahl, schwache Passwörter, CSRF/XSS im Dashboard, verwaiste Sessions, überprivilegierte Accounts.

Mitigation:
- Argon2id, TOTP, Least-Privilege RBAC, Security-Headers (CSP, HSTS), CSRF-Tokens, kurze Session-Timeouts, Audit-Logs, Key-Rotation.
