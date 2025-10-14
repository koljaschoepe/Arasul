import type { Request, Response, NextFunction } from 'express';

export function sessionTimeout(req: Request, res: Response, next: NextFunction) {
  const session = req.session as any;
  if (session.user) {
    // Absolute Timeout (8h)
    if (!session.createdAt) session.createdAt = Date.now();
    if (session.createdAt + 8*60*60*1000 < Date.now()) {
      req.session.destroy(() => {});
      return res.status(401).json({ error: 'Session abgelaufen' });
    }
    
    // Idle Timeout (15min)
    if (session.lastActivity && session.lastActivity + 15*60*1000 < Date.now()) {
      req.session.destroy(() => {});
      return res.status(401).json({ error: 'Session inaktiv' });
    }
    
    session.lastActivity = Date.now();
  }
  next();
}

