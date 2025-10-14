import { Router } from 'express';
import { prisma } from '../utils/prisma.js';
import { requireRoles } from '../middlewares/rbac.js';
import { writeAudit } from '../services/auditService.js';

const router = Router();

router.get('/', requireRoles(['admin']), async (_req, res) => {
  const roles = await prisma.role.findMany();
  res.json(roles);
});

router.post('/', requireRoles(['admin']), async (req, res) => {
  const actor = (req.session as any).user?.id as string | undefined;
  const { name, description, isActive } = req.body as any;
  const created = await prisma.role.create({ data: { name, description, isActive: isActive ?? true } });
  await writeAudit({ actorUserId: actor || null, entityType: 'Role', action: 'CREATE', targetRoleId: created.id, after: created });
  res.status(201).json(created);
});

router.put('/:id', requireRoles(['admin']), async (req, res) => {
  const actor = (req.session as any).user?.id as string | undefined;
  const id: string = req.params.id as string;
  const before = await prisma.role.findUnique({ where: { id } });
  if (!before) return res.status(404).json({ error: 'not found' });
  const { name, description, isActive } = req.body as any;
  const updated = await prisma.role.update({ where: { id }, data: { name, description, isActive } });
  await writeAudit({ actorUserId: actor || null, entityType: 'Role', action: 'UPDATE', targetRoleId: id ?? null, before, after: updated });
  res.json(updated);
});

router.delete('/:id', requireRoles(['admin']), async (req, res) => {
  const actor = (req.session as any).user?.id as string | undefined;
  const id: string = req.params.id as string;
  const before = await prisma.role.findUnique({ where: { id } });
  if (!before) return res.status(404).json({ error: 'not found' });
  await prisma.role.update({ where: { id }, data: { isActive: false } });
  await writeAudit({ actorUserId: actor || null, entityType: 'Role', action: 'DEACTIVATE', targetRoleId: id ?? null, before });
  res.status(204).end();
});

export default router;
