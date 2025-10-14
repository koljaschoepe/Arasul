import { prisma } from '../utils/prisma.js';

type AuditInput = {
  actorUserId?: string | null;
  entityType: string;
  action: string;
  targetUserId?: string | null;
  targetRoleId?: string | null;
  before?: unknown;
  after?: unknown;
};

export async function writeAudit(evt: AuditInput) {
  return prisma.auditEvent.create({ data: {
    actorUserId: evt.actorUserId || null,
    entityType: evt.entityType,
    action: evt.action,
    targetUserId: evt.targetUserId || null,
    targetRoleId: evt.targetRoleId || null,
    before: evt.before as any,
    after: evt.after as any,
  }});
}
