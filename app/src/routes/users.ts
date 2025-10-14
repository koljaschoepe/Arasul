import { Router } from 'express';
import { prisma } from '../utils/prisma.js';
import { requireRoles } from '../middlewares/rbac.js';
import { hashPassword, validatePasswordPolicy } from '../services/authService.js';
import { writeAudit } from '../services/auditService.js';

const router = Router();

router.get('/', requireRoles(['admin']), async (_req, res) => {
  const users = await prisma.user.findMany({ include: { roles: { include: { role: true } } } });
  res.json(users);
});

router.post('/', requireRoles(['admin']), async (req, res) => {
  const actor = (req.session as any).user?.id as string | undefined;
  const { email, name, password, isActive } = req.body as any;
  
  // Passwort-Policy-Validierung
  const validation = validatePasswordPolicy(password, email);
  if (!validation.valid) {
    return res.status(400).json({ errors: validation.errors });
  }
  
  const passwordHash = await hashPassword(password);
  const created = await prisma.user.create({ data: { email, name, passwordHash, isActive: isActive ?? true } });
  await writeAudit({ actorUserId: actor || null, entityType: 'User', action: 'CREATE', targetUserId: created.id, after: created });
  res.status(201).json(created);
});

router.put('/:id', requireRoles(['admin']), async (req, res) => {
  const actor = (req.session as any).user?.id as string | undefined;
  const id: string = req.params.id as string;
  const before = await prisma.user.findUnique({ where: { id } });
  if (!before) return res.status(404).json({ error: 'not found' });
  const { email, name, isActive } = req.body as any;
  const updated = await prisma.user.update({ where: { id }, data: { email, name, isActive } });
  await writeAudit({ actorUserId: actor || null, entityType: 'User', action: 'UPDATE', targetUserId: id ?? null, before, after: updated });
  res.json(updated);
});

router.delete('/:id', requireRoles(['admin']), async (req, res) => {
  const actor = (req.session as any).user?.id as string | undefined;
  const id: string = req.params.id as string;
  const before = await prisma.user.findUnique({ where: { id } });
  if (!before) return res.status(404).json({ error: 'not found' });
  await prisma.user.update({ where: { id }, data: { isActive: false } });
  await writeAudit({ actorUserId: actor || null, entityType: 'User', action: 'DEACTIVATE', targetUserId: id ?? null, before });
  res.status(204).end();
});

router.post('/:id/roles', requireRoles(['admin']), async (req, res) => {
  const actor = (req.session as any).user?.id as string | undefined;
  const id: string = req.params.id as string;
  const { roleIds } = req.body as { roleIds: string[] };
  // sync roles
  await prisma.userRole.deleteMany({ where: { userId: id as string } });
  for (const roleId of roleIds) {
    await prisma.userRole.create({ data: { userId: id as string, roleId } });
  }
  await writeAudit({ actorUserId: actor || null, entityType: 'User', action: 'ASSIGN_ROLES', targetUserId: id ?? null, after: { roleIds } });
  res.json({ ok: true });
});

export default router;
