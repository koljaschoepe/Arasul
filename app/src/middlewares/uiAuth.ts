import type { Request, Response, NextFunction } from 'express';

export function requireUiAuth(req: Request, res: Response, next: NextFunction) {
  const user = (req.session as any)?.user as { id: string; roles: string[] } | undefined;
  if (!user) return res.redirect('/admin/login');
  next();
}

export function requireUiRole(role: string) {
  return (req: Request, res: Response, next: NextFunction) => {
    const user = (req.session as any)?.user as { id: string; roles: string[] } | undefined;
    if (!user) return res.redirect('/admin/login');
    if (!user.roles.includes(role)) return res.status(403).send('Forbidden');
    next();
  };
}
