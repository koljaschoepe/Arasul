# Shard 04: Dashboard-First UX

- Landing `/dashboard`: Live-Metriken (CPU/GPU/RAM/Disk/Net, ~2s Interval), Service-Kacheln (n8n/MinIO/Guacamole/Monitoring), Systeminfo (Hostname, Uptime, WireGuard-IP), Admin-Aktionen (Restart Services, Update, Reboot, Terminal öffnen/Guacamole).
- Guacamole-Integration: Standardmäßig Iframe im Dashboard; optionaler Button „In neuem Tab öffnen“ für Admins. Iframe-URL: `/guacamole/#/client/<conn-id>?embed=true`.
- UI: Tailwind, dunkles Standard-Theme, responsive.

---

## Admin-UX: Benutzer & Rollen (MVP)

- Navigation: `Settings → Users & Roles` (nur `admin`).
- Benutzerliste:
  - Spalten: Name, Username/E-Mail, Status (aktiv/inaktiv), Rollen (Badges), 2FA (An/Aus), Letzter Login.
  - Aktionen: Erstellen, Bearbeiten, Deaktivieren/Aktivieren, Passwort-Reset, Rollen zuweisen/entziehen.
  - Suche/Filter: Textsuche (Name/Email), Filter nach Rolle, Status, 2FA.
- Rollenliste:
  - Spalten: Rollenname, Beschreibung, Status, Benutzeranzahl.
  - Aktionen: Erstellen, Umbenennen/Beschreibung ändern, Deaktivieren/Aktivieren.
- Formulare:
  - Benutzer erstellen/bearbeiten: Pflichtfelder Name, Username/E-Mail, optional 2FA voraussetzen (Org-Flag beachten), Rollen-Multi-Select.
  - Rolle erstellen/bearbeiten: Name, Beschreibung, aktiv/inaktiv.
- Zuweisung UX:
  - In Benutzer-Detail: Rollen als Multi-Select; Änderungen mit Bestätigung und Erfolgs-/Fehler-Toast.
- Fehler-/Feedback:
  - Klare Validierungsfehler; Aktionen bestätigen Erfolg/Fehlschlag (Toasts), Undo falls möglich (z. B. Re-Enable).
- Security-Hinweise:
  - 2FA-Setup-Link zeigt QR/Secret und Recovery-Codes nach Verifizierung; Codes einmalig anzeigbar und zum Download (TXT) anbietbar.
  - Admin-Aktionen erzeugen Audit-Events; sensible Felder nie im Klartext anzeigen.
