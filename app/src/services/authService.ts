import argon2 from 'argon2';
import bcrypt from 'bcrypt';
import { prisma } from '../utils/prisma.js';
import type { Prisma } from '@prisma/client';
import { authenticator } from 'otplib';
import zxcvbn from 'zxcvbn';

const COMMON_PASSWORDS = ['password', 'admin123', '123456', 'qwerty', 'letmein', 'welcome'];

// Passwort-Policy-Validierung
export function validatePasswordPolicy(password: string, email: string): { valid: boolean; errors: string[] } {
  const errors: string[] = [];
  
  // Mindestlänge 12
  if (password.length < 12) {
    errors.push('Passwort muss mindestens 12 Zeichen lang sein');
  }
  
  // Zxcvbn-Stärke ≥ 3
  const result = zxcvbn(password, [email]);
  if (result.score < 3) {
    errors.push('Passwort ist zu schwach. Verwenden Sie eine Kombination aus Buchstaben, Zahlen und Sonderzeichen.');
  }
  
  // Blacklist
  if (COMMON_PASSWORDS.some(p => password.toLowerCase().includes(p))) {
    errors.push('Passwort ist zu häufig verwendet. Wählen Sie ein sichereres Passwort.');
  }
  
  return { valid: errors.length === 0, errors };
}

export async function verifyPassword(plain: string, hash: string) {
  // Hybrid-Verifikation: Unterstütze sowohl Argon2id als auch bcrypt (für Migration)
  try {
    // Versuche zuerst Argon2id
    if (hash.startsWith('$argon2')) {
      return await argon2.verify(hash, plain);
    }
    // Fallback auf bcrypt für bestehende Hashes
    return await bcrypt.compare(plain, hash);
  } catch {
    return false;
  }
}

export async function hashPassword(plain: string) {
  return argon2.hash(plain, { 
    type: argon2.argon2id,
    memoryCost: 2 ** 16, // 64 MB
    timeCost: 3,
    parallelism: 1
  });
}

export function generateTotpSecret() {
  const secret = authenticator.generateSecret();
  return secret;
}

export function verifyTotp(token: string, secret: string) {
  return authenticator.verify({ token, secret });
}

// Recovery-Codes generieren
export function generateRecoveryCodes(count = 10): string[] {
  return Array.from({ length: count }, () => {
    // Generiere 8-stelligen Hex-Code (4 bytes)
    const bytes = Math.random().toString(36).substring(2, 10).toUpperCase();
    return bytes.padEnd(8, '0');
  });
}

// TOTP-URI für QR-Code generieren
export function generateTotpUri(email: string, secret: string): string {
  return authenticator.keyuri(email, 'Jetson Dashboard', secret);
}

export type UserWithRolesAndRecovery = Prisma.UserGetPayload<{
  select: {
    id: true;
    email: true;
    name: true;
    passwordHash: true;
    isActive: true;
    twoFactorEnabled: true;
    twoFactorSecret: true;
    recoveryCodes: true;
    roles: { select: { role: true } };
  };
}>;

export async function getUserWithRolesByEmail(email: string): Promise<UserWithRolesAndRecovery | null> {
  // Selektiere explizit alle benötigten Felder, damit die Typen vollständig sind
  return prisma.user.findUnique({
    where: { email },
    select: {
      id: true,
      email: true,
      name: true,
      passwordHash: true,
      isActive: true,
      twoFactorEnabled: true,
      twoFactorSecret: true,
      recoveryCodes: true,
      roles: { select: { role: true } },
    },
  });
}
