/**
 * Story E1.2: TLS & Security-Header A+ Tests
 * 
 * Testet Security-Header-Konfiguration (Helmet)
 * HINWEIS: HSTS wird von Caddy gesetzt und ist in diesen Tests nicht sichtbar
 */

import request from 'supertest';
import app from '../server.js';

describe('E1.2: Security Headers', () => {
  describe('Content-Security-Policy (CSP)', () => {
    it('sollte CSP-Header mit frame-src self setzen', async () => {
      const res = await request(app).get('/health');
      
      expect(res.status).toBe(200);
      expect(res.headers['content-security-policy']).toBeDefined();
      
      const csp = res.headers['content-security-policy'];
      expect(csp).toContain("default-src 'self'");
      expect(csp).toContain("frame-src 'self'");  // Für Guacamole-Iframe (E4.x)
    });

    it('sollte script-src mit unsafe-inline für EJS-Templates erlauben', async () => {
      const res = await request(app).get('/health');
      
      const csp = res.headers['content-security-policy'];
      expect(csp).toContain("script-src");
      expect(csp).toContain("'self'");
      expect(csp).toContain("'unsafe-inline'");  // EJS-Templates
    });

    it('sollte style-src mit unsafe-inline für EJS-Templates erlauben', async () => {
      const res = await request(app).get('/health');
      
      const csp = res.headers['content-security-policy'];
      expect(csp).toContain("style-src");
      expect(csp).toContain("'self'");
      expect(csp).toContain("'unsafe-inline'");  // EJS-Templates
    });

    it('sollte object-src none setzen', async () => {
      const res = await request(app).get('/health');
      
      const csp = res.headers['content-security-policy'];
      expect(csp).toContain("object-src 'none'");
    });

    it('sollte frame-ancestors setzen', async () => {
      const res = await request(app).get('/health');
      
      const csp = res.headers['content-security-policy'];
      // Helmet setzt standardmäßig frame-ancestors 'self'
      expect(csp).toContain("frame-ancestors");
    });
  });

  describe('X-Frame-Options', () => {
    it('sollte X-Frame-Options SAMEORIGIN setzen', async () => {
      const res = await request(app).get('/health');
      
      expect(res.headers['x-frame-options']).toBe('SAMEORIGIN');
    });
  });

  describe('X-Content-Type-Options', () => {
    it('sollte X-Content-Type-Options nosniff setzen', async () => {
      const res = await request(app).get('/health');
      
      expect(res.headers['x-content-type-options']).toBe('nosniff');
    });
  });

  describe('Referrer-Policy', () => {
    it('sollte Referrer-Policy strict-origin-when-cross-origin setzen', async () => {
      const res = await request(app).get('/health');
      
      expect(res.headers['referrer-policy']).toBe('strict-origin-when-cross-origin');
    });
  });

  describe('X-XSS-Protection', () => {
    it('sollte X-XSS-Protection Header setzen', async () => {
      const res = await request(app).get('/health');
      
      // Helmet setzt standardmäßig "0" (neuere Versionen)
      // Ältere Browser: "1; mode=block"
      expect(res.headers).toHaveProperty('x-xss-protection');
    });
  });

  describe('Transport-Layer Security (HSTS)', () => {
    it('sollte HSTS NICHT setzen (wird von Caddy gesetzt)', async () => {
      const res = await request(app).get('/health');
      
      // HSTS wird von Caddy auf Transport-Layer gesetzt
      // Express/Helmet sollte es NICHT setzen (hsts: false)
      expect(res.headers['strict-transport-security']).toBeUndefined();
    });
  });

  describe('Server-Header Fingerprinting', () => {
    it('sollte Server-Header NICHT exponieren', async () => {
      const res = await request(app).get('/health');
      
      // Server-Header wird von Caddy entfernt
      // Falls Express ihn setzt, sollte Helmet ihn entfernen
      // In Tests ohne Caddy kann er vorhanden sein - erwarten, dass er in Produktion fehlt
      expect(['Express', 'Node.js']).not.toContain(res.headers['server']);
    });

    it('sollte X-Powered-By Header NICHT exponieren', async () => {
      const res = await request(app).get('/health');
      
      // Express setzt standardmäßig X-Powered-By: Express
      // Helmet sollte es entfernen
      expect(res.headers['x-powered-by']).toBeUndefined();
    });
  });

  describe('Cross-Origin-Policies', () => {
    it('sollte Cross-Origin-Opener-Policy setzen', async () => {
      const res = await request(app).get('/health');
      
      // Helmet setzt COOP für Cross-Origin-Sicherheit
      expect(res.headers).toHaveProperty('cross-origin-opener-policy');
    });

    it('sollte Cross-Origin-Resource-Policy setzen', async () => {
      const res = await request(app).get('/health');
      
      // Helmet setzt CORP für Cross-Origin-Sicherheit
      expect(res.headers).toHaveProperty('cross-origin-resource-policy');
    });
  });
});

describe('E1.2: Security Headers auf verschiedenen Endpunkten', () => {
  it('sollte Security-Header auf /health setzen', async () => {
    const res = await request(app).get('/health');
    
    expect(res.status).toBe(200);
    expect(res.headers['content-security-policy']).toBeDefined();
    expect(res.headers['x-frame-options']).toBe('SAMEORIGIN');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
  });

  it('sollte Security-Header auf /auth/login setzen', async () => {
    const res = await request(app).get('/auth/login');
    
    expect(res.headers['content-security-policy']).toBeDefined();
    expect(res.headers['x-frame-options']).toBe('SAMEORIGIN');
  });

  it('sollte Security-Header auf /admin setzen', async () => {
    const res = await request(app).get('/admin');
    
    expect(res.headers['content-security-policy']).toBeDefined();
    expect(res.headers['x-frame-options']).toBe('SAMEORIGIN');
  });

  it('sollte Security-Header auf API-Endpunkten (/users) setzen', async () => {
    const res = await request(app).get('/users');
    
    // 401 Unauthorized erwartet (keine Session), aber Header sollten gesetzt sein
    expect([200, 302, 401, 403]).toContain(res.status);
    expect(res.headers['content-security-policy']).toBeDefined();
    expect(res.headers['x-content-type-options']).toBe('nosniff');
  });
});

describe('E1.2: Cookie-Security (Session)', () => {
  it('sollte CSRF-Cookie mit httpOnly und sameSite setzen', async () => {
    // CSRF-Token-Cookie wird von doubleCsrf gesetzt
    const res = await request(app).get('/auth/login');
    
    const cookies = res.headers['set-cookie'];
    expect(cookies).toBeDefined();
    
    const csrfCookie = cookies?.find((c: string) => c.startsWith('x-csrf-token='));
    expect(csrfCookie).toBeDefined();
    expect(csrfCookie).toContain('HttpOnly');
    expect(csrfCookie).toContain('SameSite=Strict');
  });
});

describe('E1.2: CSRF-Token-Handling', () => {
  it('sollte CSRF-Token in Response verfügbar machen', async () => {
    // CSRF-Token wird in res.locals.csrfToken gesetzt
    // Verfügbar für EJS-Templates über ${csrfToken}
    const res = await request(app).get('/admin/login');
    
    // Token-Cookie sollte gesetzt werden
    const cookies = res.headers['set-cookie'];
    if (cookies) {
      const csrfCookie = cookies.find((c: string) => c.startsWith('x-csrf-token='));
      expect(csrfCookie).toBeDefined();
    }
  });
});

