import type { Request, Response, NextFunction } from 'express';
import { writeAudit } from '../services/auditService.js';

export function requireRoles(required: string[]) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const user = (req.session as any)?.user as { id: string; roles: string[] } | undefined;
    if (!user) return res.status(401).json({ error: 'unauthenticated' });
    const has = required.some(r => user.roles.includes(r));
    if (!has) {
      // Audit-Event bei 403 schreiben
      await writeAudit({
        actorUserId: user.id,
        entityType: 'Access',
        action: 'DENIED',
        after: { 
          endpoint: req.path, 
          method: req.method, 
          ip: req.ip,
          requiredRoles: required,
          userRoles: user.roles
        }
      });
      return res.status(403).json({ error: 'forbidden' });
    }
    next();
  };
}
