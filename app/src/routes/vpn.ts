import { Router } from 'express';
import type { Request, Response } from 'express';
import { requireRoles } from '../middlewares/rbac.js';
import { exec } from 'child_process';
import { promisify } from 'util';
import { writeAudit } from '../services/auditService.js';

const router = Router();
const execAsync = promisify(exec);

/**
 * GET /api/vpn/status - WireGuard VPN Status
 * Story E1.3 - VPN-only Erreichbarkeit
 * 
 * Nur für Admins zugänglich
 * Zeigt aktive VPN-Verbindungen und Statistiken
 */
router.get('/status', requireRoles(['admin']), async (req: Request, res: Response) => {
  try {
    const actor = (req.session as any).user?.id as string | undefined;
    
    // WireGuard-Status abrufen
    const { stdout } = await execAsync('wg show wg0 dump');
    const lines = stdout.trim().split('\n');
    
    if (lines.length === 0) {
      return res.status(500).json({ error: 'WireGuard nicht aktiv' });
    }
    
    // Erste Zeile: Interface-Info (privatekey, publickey, listenport, fwmark)
    const [interfaceLine, ...peerLines] = lines;
    
    if (!interfaceLine) {
      return res.status(500).json({ error: 'WireGuard-Interface nicht gefunden' });
    }
    
    const [, publicKey, listenPort] = interfaceLine.split('\t');
    
    if (!publicKey || !listenPort) {
      return res.status(500).json({ error: 'Ungültige WireGuard-Konfiguration' });
    }
    
    // Peer-Informationen parsen
    const peers = peerLines.map(peer => {
      const [pubkey, , endpoint, allowedIps, latestHandshake, rxBytes, txBytes] = peer.split('\t');
      
      if (!pubkey) {
        return null;
      }
      
      return {
        publicKey: pubkey.substring(0, 16) + '...', // Gekürzt für Security
        endpoint: endpoint || 'nicht verbunden',
        allowedIps: allowedIps || '',
        latestHandshake: latestHandshake === '0' ? 'nie' : new Date(parseInt(latestHandshake || '0') * 1000).toISOString(),
        rxBytes: parseInt(rxBytes || '0') || 0,
        txBytes: parseInt(txBytes || '0') || 0,
        active: parseInt(latestHandshake || '0') > 0 && (Date.now() / 1000 - parseInt(latestHandshake || '0')) < 300 // Aktiv wenn Handshake < 5 min
      };
    }).filter((p): p is NonNullable<typeof p> => p !== null);
    
    // Audit-Log
    await writeAudit({ 
      actorUserId: actor || null, 
      entityType: 'VPN', 
      action: 'VIEW_STATUS' 
    });
    
    res.json({
      interface: 'wg0',
      publicKey: publicKey.substring(0, 16) + '...',
      listenPort: parseInt(listenPort),
      peersCount: peers.length,
      peersActive: peers.filter(p => p.active).length,
      peers
    });
  } catch (error) {
    console.error('VPN-Status-Fehler:', error);
    
    // Prüfe ob WireGuard überhaupt installiert ist
    try {
      await execAsync('which wg');
      return res.status(500).json({ error: 'WireGuard-Service nicht aktiv oder wg0 nicht konfiguriert' });
    } catch {
      return res.status(500).json({ error: 'WireGuard nicht installiert' });
    }
  }
});

/**
 * GET /api/vpn/health - VPN Health-Check
 * Einfacher Check ob VPN-Service läuft
 * Zugänglich für alle authentifizierten Benutzer
 */
router.get('/health', async (req: Request, res: Response) => {
  try {
    await execAsync('systemctl is-active wg-quick@wg0');
    res.json({ status: 'ok', vpn: 'active' });
  } catch {
    res.status(503).json({ status: 'degraded', vpn: 'inactive' });
  }
});

export default router;

