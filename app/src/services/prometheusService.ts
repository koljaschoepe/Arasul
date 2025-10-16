import type { Request, Response, NextFunction } from 'express';
import client from 'prom-client';

/**
 * Prometheus Metrics Service
 * Story E1.2: Security-Header-Monitoring
 * 
 * Exportiert Metriken über Security-Header, TLS und System-Health
 */

// Register für alle Metriken
const register = new client.Registry();

// Default-Metriken (CPU, Memory, etc.)
client.collectDefaultMetrics({ register });

// ============================================================================
// Security-Header Metriken
// ============================================================================

// Gauge: Security-Header Status (1 = vorhanden, 0 = fehlt)
const securityHeaderStatus = new client.Gauge({
  name: 'security_header_status',
  help: 'Status of security headers (1 = present, 0 = missing)',
  labelNames: ['header_name', 'endpoint'],
  registers: [register],
});

// Counter: Requests mit fehlenden Security-Headern
const missingHeadersCounter = new client.Counter({
  name: 'security_headers_missing_total',
  help: 'Total number of requests with missing security headers',
  labelNames: ['header_name', 'endpoint'],
  registers: [register],
});

// Gauge: TLS-Version (1.2 = 12, 1.3 = 13)
const tlsVersionGauge = new client.Gauge({
  name: 'tls_version',
  help: 'TLS protocol version in use',
  labelNames: ['version'],
  registers: [register],
});

// Gauge: Zertifikatsablauf (Sekunden bis Ablauf)
const certExpiryGauge = new client.Gauge({
  name: 'tls_certificate_expiry_seconds',
  help: 'Seconds until TLS certificate expiry',
  registers: [register],
});

// ============================================================================
// Application Metriken
// ============================================================================

// Counter: HTTP-Requests
const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register],
});

// Histogram: Request-Latenz
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
  registers: [register],
});

// Gauge: Aktive Sessions
const activeSessionsGauge = new client.Gauge({
  name: 'active_sessions_total',
  help: 'Total number of active user sessions',
  registers: [register],
});

// ============================================================================
// Security-Header Tracking Middleware
// ============================================================================

/**
 * Middleware zum Tracking von Security-Headern
 */
export function trackSecurityHeaders(req: Request, res: Response, next: NextFunction) {
  const originalSend = res.send;

  res.send = function (data: any) {
    // Liste der erwarteten Security-Header
    const requiredHeaders = [
      'strict-transport-security',
      'content-security-policy',
      'x-frame-options',
      'x-content-type-options',
      'referrer-policy',
      'cross-origin-opener-policy',
      'cross-origin-resource-policy',
    ];

    // Endpoint-Name (für Labels)
    const endpoint = req.route?.path || req.path;

    // Prüfen welche Header gesetzt sind
    requiredHeaders.forEach((headerName) => {
      const isPresent = res.hasHeader(headerName) ? 1 : 0;
      
      securityHeaderStatus.set({ header_name: headerName, endpoint }, isPresent);
      
      if (isPresent === 0) {
        missingHeadersCounter.inc({ header_name: headerName, endpoint });
      }
    });

    return originalSend.call(this, data);
  };

  next();
}

/**
 * Middleware zum Tracking von HTTP-Metriken
 */
export function trackHttpMetrics(req: Request, res: Response, next: NextFunction) {
  const start = Date.now();

  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route?.path || req.path;
    const method = req.method;
    const statusCode = res.statusCode.toString();

    httpRequestCounter.inc({ method, route, status_code: statusCode });
    httpRequestDuration.observe({ method, route, status_code: statusCode }, duration);
  });

  next();
}

/**
 * Session-Tracking für Prometheus
 */
export function updateActiveSessionsMetric(count: number) {
  activeSessionsGauge.set(count);
}

/**
 * TLS-Version-Tracking
 */
export function updateTlsVersionMetric(version: string) {
  const versionNumber = version === 'TLSv1.3' ? 13 : version === 'TLSv1.2' ? 12 : 0;
  tlsVersionGauge.set({ version }, versionNumber);
}

/**
 * Zertifikatsablauf-Tracking (Sekunden bis Ablauf)
 */
export function updateCertExpiryMetric(expiryDate: Date) {
  const now = new Date();
  const secondsUntilExpiry = (expiryDate.getTime() - now.getTime()) / 1000;
  certExpiryGauge.set(secondsUntilExpiry);
}

/**
 * Prometheus Metrics Endpoint Handler
 */
export async function metricsHandler(req: Request, res: Response) {
  res.set('Content-Type', register.contentType);
  const metrics = await register.metrics();
  res.end(metrics);
}

/**
 * Health-Check mit Prometheus-Integration
 */
export function healthCheckHandler(req: Request, res: Response) {
  // Basis-Health-Check
  const health = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  };

  res.json(health);
}

// ============================================================================
// Initialisierung
// ============================================================================

// TLS-Version Initial setzen (wird von Caddy terminiert)
updateTlsVersionMetric('TLSv1.3');

// Hinweis: Zertifikatsablauf wird von externem Monitoring-Skript gesetzt
// (siehe scripts/monitor-cert-expiry.sh)

