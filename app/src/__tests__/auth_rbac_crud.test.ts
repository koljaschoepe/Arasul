import request from 'supertest';
import app from '../server.js';
import { prisma } from '../utils/prisma.js';
import bcrypt from 'bcrypt';

async function loginAsAdmin(agent: request.SuperAgentTest) {
  const res = await agent.post('/auth/login').send({ email: 'admin@example.com', password: 'admin123' });
  expect(res.status).toBe(200);
}

describe('Auth/RBAC/CRUD', () => {
  const agent = request.agent(app);

  beforeAll(async () => {
    // Ensure admin role and user exist and 2FA is disabled
    const adminRole = await prisma.role.upsert({
      where: { name: 'admin' },
      update: {},
      create: { name: 'admin', isActive: true },
    });
    const adminUser = await prisma.user.upsert({
      where: { email: 'admin@example.com' },
      update: { twoFactorEnabled: false, twoFactorSecret: null },
      create: {
        email: 'admin@example.com',
        name: 'Admin',
        passwordHash: await bcrypt.hash('admin123', 10),
        isActive: true,
        twoFactorEnabled: false,
      },
    });
    await prisma.userRole.upsert({
      where: { userId_roleId: { userId: adminUser.id, roleId: adminRole.id } },
      update: {},
      create: { userId: adminUser.id, roleId: adminRole.id },
    });
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('health ok', async () => {
    const res = await agent.get('/health');
    expect(res.status).toBe(200);
  });

  it('requires auth for users list', async () => {
    const res = await agent.get('/users');
    expect(res.status).toBe(401);
  });

  it('admin can list users', async () => {
    await loginAsAdmin(agent);
    const res = await agent.get('/users');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  it('admin can create/update/deactivate user and assign roles', async () => {
    await loginAsAdmin(agent);
    const email = `u_${Date.now()}@example.com`;
    const created = await agent.post('/users').send({ email, name: 'U1', password: 'SecureTestPass123!' });
    expect(created.status).toBe(201);
    const userId = created.body.id;

    const updated = await agent.put(`/users/${userId}`).send({ name: 'U1b' });
    expect(updated.status).toBe(200);

    const roles = await prisma.role.findMany();
    const assign = await agent.post(`/users/${userId}/roles`).send({ roleIds: [roles[0].id] });
    expect(assign.status).toBe(200);

    const del = await agent.delete(`/users/${userId}`);
    expect(del.status).toBe(204);
  });

  it('admin can manage roles', async () => {
    await loginAsAdmin(agent);
    const roleName = `ops_${Date.now()}`;
    const created = await agent.post('/roles').send({ name: roleName, description: 'ops' });
    expect(created.status).toBe(201);
    const roleId = created.body.id;

    const updated = await agent.put(`/roles/${roleId}`).send({ description: 'ops2' });
    expect(updated.status).toBe(200);

    const del = await agent.delete(`/roles/${roleId}`);
    expect(del.status).toBe(204);
  });
});
