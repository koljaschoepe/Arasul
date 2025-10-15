# Multi-stage Build für Node.js Backend (Story E1.1)

# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

# Dependencies installieren (cached wenn package.json unverändert)
COPY package*.json ./
RUN npm ci --only=production

# TypeScript Build
COPY . .
RUN npm run build

# Stage 2: Production
FROM node:20-alpine

WORKDIR /app

# Nur Production-Dependencies und Build-Output kopieren
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/public ./public

# Prisma Client generieren
RUN npx prisma generate

# Non-root User für Security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001
USER nodejs

# Port exponieren (intern im Docker-Netzwerk)
EXPOSE 3000

# Health-Check
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start-Command
CMD ["node", "dist/server.js"]

