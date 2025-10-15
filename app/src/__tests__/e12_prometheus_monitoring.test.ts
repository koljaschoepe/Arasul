/**
 * Test Suite: Prometheus Monitoring Integration
 * Story E1.2 Phase 1.5
 * 
 * Tests für:
 * - Prometheus Metriken-Exporter
 * - Security-Header-Tracking
 * - Alert-Validierung
 */

import request from 'supertest';
import express from 'express';
import { 
  trackSecurityHeaders, 
  trackHttpMetrics, 
  metricsHandler,
  updateCertExpiryMetric,
  updateTlsVersionMetric,
  updateActiveSessionsMetric
} from '../services/prometheusService';

describe('E1.2 Phase 1.5: Prometheus Monitoring', () => {
  let app: express.Application;

  beforeEach(() => {
    app = express();
    
    // Middleware registrieren
    app.use(trackHttpMetrics);
    app.use(trackSecurityHeaders);
    
    // Test-Route mit Security-Headern
    app.get('/test', (req, res) => {
      res.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
      res.set('Content-Security-Policy', "default-src 'self'");
      res.set('X-Frame-Options', 'SAMEORIGIN');
      res.set('X-Content-Type-Options', 'nosniff');
      res.set('Referrer-Policy', 'strict-origin-when-cross-origin');
      res.json({ status: 'ok' });
    });
    
    // Test-Route OHNE Security-Header
    app.get('/insecure', (req, res) => {
      res.json({ status: 'insecure' });
    });
    
    // Metrics-Endpoint
    app.get('/metrics', metricsHandler);
  });

  // ==========================================================================
  // Prometheus Metriken-Endpoint
  // ==========================================================================

  describe('Metriken-Endpoint', () => {
    it('sollte Metriken im Prometheus-Format zurückgeben', async () => {
      const res = await request(app).get('/metrics');
      
      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toContain('text/plain');
      expect(res.text).toContain('# HELP');
      expect(res.text).toContain('# TYPE');
    });

    it('sollte Security-Header-Metriken enthalten', async () => {
      // Request ausführen um Metriken zu generieren
      await request(app).get('/test');
      
      const res = await request(app).get('/metrics');
      
      expect(res.text).toContain('security_header_status');
      expect(res.text).toContain('header_name="strict-transport-security"');
    });

    it('sollte HTTP-Metriken enthalten', async () => {
      await request(app).get('/test');
      
      const res = await request(app).get('/metrics');
      
      expect(res.text).toContain('http_requests_total');
      expect(res.text).toContain('http_request_duration_seconds');
    });

    it('sollte TLS-Metriken enthalten', async () => {
      updateTlsVersionMetric('TLSv1.3');
      
      const res = await request(app).get('/metrics');
      
      expect(res.text).toContain('tls_version');
    });

    it('sollte Zertifikatsablauf-Metriken enthalten', async () => {
      const futureDate = new Date();
      futureDate.setDate(futureDate.getDate() + 30);
      updateCertExpiryMetric(futureDate);
      
      const res = await request(app).get('/metrics');
      
      expect(res.text).toContain('tls_certificate_expiry_seconds');
    });
  });

  // ==========================================================================
  // Security-Header-Tracking
  // ==========================================================================

  describe('Security-Header-Tracking', () => {
    it('sollte vorhandene Security-Header tracken', async () => {
      await request(app).get('/test');
      
      const res = await request(app).get('/metrics');
      
      // Header sollten als vorhanden (1) markiert sein
      expect(res.text).toMatch(/security_header_status\{.*header_name="strict-transport-security".*\} 1/);
      expect(res.text).toMatch(/security_header_status\{.*header_name="content-security-policy".*\} 1/);
      expect(res.text).toMatch(/security_header_status\{.*header_name="x-frame-options".*\} 1/);
    });

    it('sollte fehlende Security-Header tracken', async () => {
      await request(app).get('/insecure');
      
      const res = await request(app).get('/metrics');
      
      // Fehlende Header sollten inkrementiert werden
      expect(res.text).toContain('security_headers_missing_total');
    });

    it('sollte Header-Status nach Endpoint unterscheiden', async () => {
      await request(app).get('/test');
      await request(app).get('/insecure');
      
      const res = await request(app).get('/metrics');
      
      // Verschiedene Endpoints sollten separate Metriken haben
      expect(res.text).toMatch(/endpoint="\/test"/);
      expect(res.text).toMatch(/endpoint="\/insecure"/);
    });
  });

  // ==========================================================================
  // HTTP-Metriken
  // ==========================================================================

  describe('HTTP-Metriken', () => {
    it('sollte HTTP-Requests nach Status-Code zählen', async () => {
      await request(app).get('/test');
      
      const res = await request(app).get('/metrics');
      
      expect(res.text).toMatch(/http_requests_total\{.*status_code="200".*\}/);
    });

    it('sollte Request-Dauer messen', async () => {
      await request(app).get('/test');
      
      const res = await request(app).get('/metrics');
      
      expect(res.text).toContain('http_request_duration_seconds_bucket');
      expect(res.text).toContain('http_request_duration_seconds_sum');
      expect(res.text).toContain('http_request_duration_seconds_count');
    });

    it('sollte Requests nach Route gruppieren', async () => {
      await request(app).get('/test');
      
      const res = await request(app).get('/metrics');
      
      expect(res.text).toMatch(/route="\/test"/);
    });
  });

  // ==========================================================================
  // TLS-Metriken
  // ==========================================================================

  describe('TLS-Metriken', () => {
    it('sollte TLS 1.3 als Version 13 tracken', async () => {
      updateTlsVersionMetric('TLSv1.3');
      
      const res = await request(app).get('/metrics');
      
      expect(res.text).toMatch(/tls_version\{.*\} 13/);
    });

    it('sollte TLS 1.2 als Version 12 tracken', async () => {
      updateTlsVersionMetric('TLSv1.2');
      
      const res = await request(app).get('/metrics');
      
      expect(res.text).toMatch(/tls_version\{.*\} 12/);
    });

    it('sollte Zertifikatsablauf in Sekunden tracken', async () => {
      const futureDate = new Date();
      futureDate.setDate(futureDate.getDate() + 30); // 30 Tage
      updateCertExpiryMetric(futureDate);
      
      const res = await request(app).get('/metrics');
      
      // Sollte ca. 30 * 24 * 60 * 60 = 2592000 Sekunden sein
      expect(res.text).toMatch(/tls_certificate_expiry_seconds \d+/);
    });
  });

  // ==========================================================================
  // Session-Metriken
  // ==========================================================================

  describe('Session-Metriken', () => {
    it('sollte aktive Sessions tracken', async () => {
      updateActiveSessionsMetric(5);
      
      const res = await request(app).get('/metrics');
      
      expect(res.text).toMatch(/active_sessions_total 5/);
    });

    it('sollte Session-Count aktualisieren', async () => {
      updateActiveSessionsMetric(5);
      let res = await request(app).get('/metrics');
      expect(res.text).toMatch(/active_sessions_total 5/);
      
      updateActiveSessionsMetric(10);
      res = await request(app).get('/metrics');
      expect(res.text).toMatch(/active_sessions_total 10/);
    });
  });

  // ==========================================================================
  // Alert-Simulation
  // ==========================================================================

  describe('Alert-Simulationen', () => {
    it('sollte HSTS-Header-Fehlen detektieren', async () => {
      // Request ohne HSTS
      await request(app).get('/insecure');
      
      const res = await request(app).get('/metrics');
      
      // security_header_status sollte 0 sein für HSTS
      expect(res.text).toMatch(/security_header_status\{.*header_name="strict-transport-security".*endpoint="\/insecure".*\} 0/);
    });

    it('sollte Zertifikatsablauf <30 Tage detektieren', async () => {
      const futureDate = new Date();
      futureDate.setDate(futureDate.getDate() + 15); // 15 Tage (< 30)
      updateCertExpiryMetric(futureDate);
      
      const res = await request(app).get('/metrics');
      
      const match = res.text.match(/tls_certificate_expiry_seconds (\d+)/);
      expect(match).toBeTruthy();
      
      const seconds = parseInt(match![1]);
      const days = seconds / (24 * 60 * 60);
      expect(days).toBeLessThan(30);
    });

    it('sollte Zertifikatsablauf <7 Tage detektieren (kritisch)', async () => {
      const futureDate = new Date();
      futureDate.setDate(futureDate.getDate() + 3); // 3 Tage (< 7)
      updateCertExpiryMetric(futureDate);
      
      const res = await request(app).get('/metrics');
      
      const match = res.text.match(/tls_certificate_expiry_seconds (\d+)/);
      expect(match).toBeTruthy();
      
      const seconds = parseInt(match![1]);
      const days = seconds / (24 * 60 * 60);
      expect(days).toBeLessThan(7);
    });

    it('sollte abgelaufenes Zertifikat detektieren', async () => {
      const pastDate = new Date();
      pastDate.setDate(pastDate.getDate() - 1); // Gestern
      updateCertExpiryMetric(pastDate);
      
      const res = await request(app).get('/metrics');
      
      const match = res.text.match(/tls_certificate_expiry_seconds (-?\d+)/);
      expect(match).toBeTruthy();
      
      const seconds = parseInt(match![1]);
      expect(seconds).toBeLessThan(0); // Negativ = abgelaufen
    });
  });

  // ==========================================================================
  // Performance-Tests
  // ==========================================================================

  describe('Performance', () => {
    it('sollte Metriken schnell generieren (<50ms)', async () => {
      const start = Date.now();
      await request(app).get('/metrics');
      const duration = Date.now() - start;
      
      expect(duration).toBeLessThan(50);
    });

    it('sollte mit vielen Requests skalieren', async () => {
      // 100 Requests ausführen
      const promises = [];
      for (let i = 0; i < 100; i++) {
        promises.push(request(app).get('/test'));
      }
      await Promise.all(promises);
      
      // Metriken sollten korrekt aggregiert sein
      const res = await request(app).get('/metrics');
      expect(res.status).toBe(200);
      expect(res.text).toContain('http_requests_total');
    });
  });
});

