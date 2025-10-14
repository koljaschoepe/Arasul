import { Router } from 'express';
import { prisma } from '../utils/prisma.js';
import { requireUiAuth, requireUiRole } from '../middlewares/uiAuth.js';
import bcrypt from 'bcrypt';
import { hashPassword } from '../services/authService.js';

const router = Router();

router.get('/login', (_req, res) => res.render('admin/login'));

router.post('/login', async (req, res) => {
  const { email, password } = req.body as any;
  const user = await prisma.user.findUnique({ where: { email }, include: { roles: { include: { role: true } } } });
  if (!user || !user.isActive) return res.render('admin/login', { error: 'Invalid credentials' });
  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) return res.render('admin/login', { error: 'Invalid credentials' });
  const roles = user.roles.filter(r => r.role.isActive).map(r => r.role.name);
  (req.session as any).user = { id: user.id, email: user.email, roles };
  res.redirect('/admin');
});

router.post('/logout', (req, res) => { req.session.destroy(() => {}); res.redirect('/admin/login'); });

router.get('/', requireUiAuth, (_req, res) => res.render('admin/index'));

router.get('/users', requireUiRole('admin'), async (_req, res) => {
  const users = await prisma.user.findMany({ include: { roles: { include: { role: true } } } });
  res.render('admin/users', { users });
});

router.get('/roles', requireUiRole('admin'), async (_req, res) => {
  const roles = await prisma.role.findMany();
  res.render('admin/roles', { roles });
});

router.post('/users', requireUiRole('admin'), async (req, res) => {
  const { email, name, password } = req.body as any;
  const passwordHash = await hashPassword(password);
  await prisma.user.create({ data: { email, name, passwordHash } });
  res.redirect('/admin/users');
});

router.post('/roles', requireUiRole('admin'), async (req, res) => {
  const { name, description } = req.body as any;
  await prisma.role.create({ data: { name, description } });
  res.redirect('/admin/roles');
});

export default router;
