# Shard 10: Netz & Ports (Default)

- WireGuard: 51820/UDP (eingehend, VPN only)
- HTTPS (Caddy): 443/TCP (nur im VPN/LAN)
- HTTP (Caddy): 80/TCP (nur im VPN) → 301 Redirect auf 443/TCP
- Interne Container-Ports: nicht extern exponiert; nur via Reverse-Proxy erreichbar
