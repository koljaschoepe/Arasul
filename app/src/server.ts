import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import session from 'express-session';
import dotenv from 'dotenv';
import rateLimit from 'express-rate-limit';
import { doubleCsrf } from 'csrf-csrf';
import authRoutes from './routes/auth.js';
import userRoutes from './routes/users.js';
import roleRoutes from './routes/roles.js';
import path from 'path';
import { fileURLToPath } from 'url';
import adminRoutes from './routes/admin.js';
import { sessionTimeout } from './middlewares/sessionTimeout.js';

dotenv.config();

// SESSION_SECRET prüfen
if (!process.env.SESSION_SECRET && process.env.NODE_ENV === 'production') {
  throw new Error('SESSION_SECRET muss in .env gesetzt sein (Produktion)');
}

const app = express();

// view engine setup
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'ejs');
app.use(express.urlencoded({ extended: true }));
app.use(helmet());
app.use(cors({ origin: true, credentials: true }));
app.use(express.json());
app.use(cookieParser());

// Session-Konfiguration mit Härtung
app.use(session({
  secret: process.env.SESSION_SECRET || 'change-me',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production', // true in Produktion
    httpOnly: true,
    sameSite: 'strict',
    maxAge: 15 * 60 * 1000 // Idle-Timeout: 15 min
  }
}));

// Session-Timeout-Middleware
app.use(sessionTimeout);

// CSRF-Schutz Konfiguration (Double Submit Cookie Pattern)
const csrfProtection = doubleCsrf({
  getSecret: () => process.env.SESSION_SECRET || 'change-me',
  getSessionIdentifier: (req) => (req.session as any)?.user?.id || '',
  cookieName: 'x-csrf-token',
  cookieOptions: {
    sameSite: 'strict',
    path: '/',
    secure: process.env.NODE_ENV === 'production',
  },
  size: 64,
  ignoredMethods: ['GET', 'HEAD', 'OPTIONS'],
});

// CSRF-Token in allen Responses verfügbar machen
app.use((req, res, next) => {
  res.locals.csrfToken = csrfProtection.generateCsrfToken(req, res);
  next();
});

// Rate-Limiting Konfiguration
// Strict Auth Rate Limit
const authLimiter = rateLimit({
  windowMs: 10 * 60 * 1000, // 10 min
  max: 5, // 5 Fehlversuche
  skipSuccessfulRequests: true,
  message: { error: 'Account temporär gesperrt nach zu vielen Fehlversuchen' },
  standardHeaders: true,
  legacyHeaders: false,
});

// General API Rate Limit
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 min
  max: 100,
  message: { error: 'Zu viele Anfragen, bitte später erneut versuchen' },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use('/public', express.static(path.join(__dirname, '..', 'public')));

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// routes
app.use('/auth/login', authLimiter); // Strenger Limiter für Login
app.use('/auth', authRoutes);
app.use('/users', apiLimiter, userRoutes);
app.use('/roles', apiLimiter, roleRoutes);
// Admin-UI: CSRF-Schutz für POST/PUT/DELETE (GET ausgenommen)
app.use('/admin', csrfProtection.doubleCsrfProtection, adminRoutes);
app.use('/', (req, res) => res.redirect('/admin'));

const port = process.env.PORT || 3000;
if (process.env.NODE_ENV !== 'test') {
  app.listen(port, () => {
    console.log(`server listening on ${port}`);
  });
}

export default app;
