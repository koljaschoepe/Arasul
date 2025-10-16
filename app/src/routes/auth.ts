import { Router } from 'express';
import type { Request, Response } from 'express';
import { prisma } from '../utils/prisma.js';
import { getUserWithRolesByEmail, verifyPassword, verifyTotp, generateTotpSecret, hashPassword, validatePasswordPolicy, generateRecoveryCodes, generateTotpUri } from '../services/authService.js';
import type { UserWithRolesAndRecovery } from '../services/authService.js';
import { writeAudit } from '../services/auditService.js';
import QRCode from 'qrcode';

const router = Router();

router.post('/login', async (req: Request, res: Response) => {
  const { email, password, totp, recoveryCode } = req.body as { email: string; password: string; totp?: string; recoveryCode?: string };
  const user: UserWithRolesAndRecovery | null = await getUserWithRolesByEmail(email);
  if (!user || !user.isActive) return res.status(401).json({ error: 'invalid credentials' });
  const ok = await verifyPassword(password, user.passwordHash);
  if (!ok) return res.status(401).json({ error: 'invalid credentials' });

  if (user.twoFactorEnabled) {
    // Prüfe zuerst Recovery-Code, dann TOTP
    if (recoveryCode) {
      const codes = JSON.parse(user.recoveryCodes || '[]') as string[];
      let validCode = false;
      let remainingCodes = codes;
      
      for (const hashedCode of codes) {
        if (await verifyPassword(recoveryCode, hashedCode)) {
          validCode = true;
          // Code verbrauchen (aus Array entfernen)
          remainingCodes = codes.filter(c => c !== hashedCode);
          await prisma.user.update({
            where: { id: user.id },
            data: { recoveryCodes: JSON.stringify(remainingCodes) } as any,
          });
          await writeAudit({ actorUserId: user.id, entityType: 'Auth', action: 'RECOVERY_LOGIN' });
          break;
        }
      }
      
      if (!validCode) {
        return res.status(401).json({ error: 'Ungültiger Recovery-Code' });
      }
    } else if (!totp || !user.twoFactorSecret || !verifyTotp(String(totp), user.twoFactorSecret)) {
      return res.status(401).json({ error: '2fa required' });
    }
  }
  const roles = user.roles.filter((r) => r.role.isActive).map((r) => r.role.name);
  (req.session as any).user = { id: user.id, email: user.email, roles };
  await writeAudit({ actorUserId: user.id, entityType: 'Auth', action: 'LOGIN' });
  return res.json({ ok: true });
});

router.post('/logout', async (req: Request, res: Response) => {
  const actor = (req.session as any).user?.id as string | undefined;
  await writeAudit({ actorUserId: actor || null, entityType: 'Auth', action: 'LOGOUT' });
  req.session.destroy(() => { /* explicit noop */ });
  res.json({ ok: true });
});

router.post('/enable-2fa', async (req: Request, res: Response) => {
  const actor = (req.session as any).user as { id: string; email: string } | undefined;
  if (!actor) return res.status(401).json({ error: 'unauthenticated' });
  
  const secret = generateTotpSecret();
  
  // Recovery-Codes generieren und hashen
  const recoveryCodes = generateRecoveryCodes();
  const hashedCodes = await Promise.all(
    recoveryCodes.map(code => hashPassword(code))
  );
  
  // TOTP-URI für QR-Code generieren
  const otpauthUrl = generateTotpUri(actor.email, secret);
  const qrCodeDataUrl = await QRCode.toDataURL(otpauthUrl);
  
  await prisma.user.update({
    where: { id: actor.id },
    data: {
      twoFactorSecret: secret,
      twoFactorEnabled: true,
      recoveryCodes: JSON.stringify(hashedCodes),
    } as any,
  });
  
  await writeAudit({ actorUserId: actor.id, entityType: 'User', action: 'ENABLE_2FA', targetUserId: actor.id });
  
  res.json({ 
    secret, 
    qrCodeDataUrl,
    recoveryCodes // Einmalige Anzeige!
  });
});

router.post('/reset-password', async (req: Request, res: Response) => {
  const actor = (req.session as any).user as { id: string } | undefined;
  if (!actor) return res.status(401).json({ error: 'unauthenticated' });
  const { userId, newPassword } = req.body as { userId: string; newPassword: string };
  const target = await prisma.user.findUnique({ where: { id: userId } });
  if (!target) return res.status(404).json({ error: 'not found' });
  
  // Passwort-Policy-Validierung
  const validation = validatePasswordPolicy(newPassword, target.email);
  if (!validation.valid) {
    return res.status(400).json({ errors: validation.errors });
  }
  
  const hash = await hashPassword(newPassword);
  await prisma.user.update({ where: { id: userId }, data: { passwordHash: hash } });
  await writeAudit({ actorUserId: actor.id, entityType: 'User', action: 'RESET_PASSWORD', targetUserId: userId });
  res.json({ ok: true });
});

export default router;
