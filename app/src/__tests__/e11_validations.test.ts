import request from 'supertest';
import app from '../server.js';
import { prisma } from '../utils/prisma.js';
import bcrypt from 'bcrypt';
import { authenticator } from 'otplib';

async function login(agent: request.SuperAgentTest, email: string, password: string, totp?: string) {
  return agent.post('/auth/login').send({ email, password, totp });
}

describe('E1.1 Validierungen: 2FA, RBAC 403, Audit', () => {
  const agent = request.agent(app);
  beforeAll(async () => {
    // Ensure clean baseline: admin user exists, 2FA disabled
    const adminRole = await prisma.role.upsert({ where: { name: 'admin' }, update: {}, create: { name: 'admin', isActive: true } });
    const adminUser = await prisma.user.upsert({
      where: { email: 'admin@example.com' },
      update: { twoFactorEnabled: false, twoFactorSecret: null },
      create: { email: 'admin@example.com', name: 'Admin', passwordHash: await bcrypt.hash('admin123', 10), isActive: true },
    });
    await prisma.userRole.upsert({ where: { userId_roleId: { userId: adminUser.id, roleId: adminRole.id } }, update: {}, create: { userId: adminUser.id, roleId: adminRole.id } });
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('erzwingt 2FA nach Aktivierung und erlaubt Login mit TOTP', async () => {
    // login als admin
    let res = await login(agent, 'admin@example.com', 'admin123');
    expect(res.status).toBe(200);

    // 2FA aktivieren
    res = await agent.post('/auth/enable-2fa').send({});
    expect(res.status).toBe(200);
    const secret = (res.body && res.body.secret) as string;
    expect(secret).toBeTruthy();

    // logout
    await agent.post('/auth/logout').send({});

    // login ohne totp sollte scheitern
    res = await login(agent, 'admin@example.com', 'admin123');
    expect(res.status).toBe(401);

    // totp generieren und login zulassen
    const token = authenticator.generate(secret);
    res = await login(agent, 'admin@example.com', 'admin123', token);
    expect(res.status).toBe(200);

    // Test-Isolation: 2FA für Admin wieder deaktivieren
    await prisma.user.update({
      where: { email: 'admin@example.com' },
      data: { twoFactorEnabled: false, twoFactorSecret: null },
    });
  });

  it('RBAC: non-admin erhält 403 auf /users', async () => {
    // admin legt user an
    let res = await login(agent, 'admin@example.com', 'admin123');
    expect(res.status).toBe(200);

    const email = `user_${Date.now()}@example.com`;
    const password = 'SecureTestPass123!';
    res = await agent.post('/users').send({ email, name: 'NoAdmin', password });
    expect(res.status).toBe(201);

    // logout admin
    await agent.post('/auth/logout').send({});

    // login als neuer user (ohne admin-rolle)
    res = await login(agent, email, password);
    expect(res.status).toBe(200);

    // zugriff auf /users verboten
    res = await agent.get('/users');
    expect(res.status).toBe(403);
  });

  it('Audit-Events werden bei User-Create geschrieben', async () => {
    const beforeCount = await prisma.auditEvent.count({ where: { entityType: 'User', action: 'CREATE' } });

    // admin legt weiteren user an
    let res = await login(agent, 'admin@example.com', 'admin123');
    expect(res.status).toBe(200);

    const email = `audit_${Date.now()}@example.com`;
    res = await agent.post('/users').send({ email, name: 'AuditUser', password: 'SecureTestPass123!' });
    expect(res.status).toBe(201);

    const afterCount = await prisma.auditEvent.count({ where: { entityType: 'User', action: 'CREATE' } });
    expect(afterCount).toBeGreaterThan(beforeCount);
  });
});
