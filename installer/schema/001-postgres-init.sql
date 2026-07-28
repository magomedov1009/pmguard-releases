CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  "telegramId" VARCHAR NOT NULL UNIQUE,
  "telegramUsername" VARCHAR,
  "firstName" VARCHAR,
  "createdAt" TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vpn_clients (
  id SERIAL PRIMARY KEY,
  "xuiId" INTEGER NOT NULL UNIQUE,
  "pmgId" VARCHAR UNIQUE,
  remark VARCHAR NOT NULL,
  protocol VARCHAR NOT NULL,
  port INTEGER NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT true,
  "expiryTime" BIGINT,
  "privateKey" TEXT,
  "publicKey" TEXT,
  "preSharedKey" TEXT,
  "allowedIp" VARCHAR,
  "serverKey" TEXT,
  "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS plans (
  id SERIAL PRIMARY KEY,
  name VARCHAR NOT NULL,
  price INTEGER NOT NULL,
  "durationDays" INTEGER NOT NULL,
  active BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS client_links (
  id SERIAL PRIMARY KEY,
  "userId" INTEGER NOT NULL,
  "vpnClientId" INTEGER NOT NULL,
  approved BOOLEAN NOT NULL DEFAULT false,
  rejected BOOLEAN NOT NULL DEFAULT false,
  "displayName" VARCHAR,
  "createdAt" TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS subscriptions (
  id SERIAL PRIMARY KEY,
  "userId" INTEGER NOT NULL,
  "vpnClientId" INTEGER NOT NULL,
  "planId" INTEGER NOT NULL,
  status VARCHAR NOT NULL DEFAULT 'active',
  "expiresAt" TIMESTAMP NOT NULL,
  "lastReminderDays" INTEGER,
  "lastReminderAt" TIMESTAMP,
  "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payments (
  id SERIAL PRIMARY KEY,
  "userId" INTEGER NOT NULL,
  "planId" INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  provider VARCHAR NOT NULL,
  "providerPaymentId" VARCHAR UNIQUE,
  status VARCHAR NOT NULL DEFAULT 'pending',
  "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_client_links_user ON client_links ("userId");
CREATE INDEX IF NOT EXISTS idx_subscriptions_user ON subscriptions ("userId");

CREATE TABLE IF NOT EXISTS audit_events (
  id SERIAL PRIMARY KEY,
  type VARCHAR NOT NULL,
  level VARCHAR NOT NULL DEFAULT 'info',
  actor VARCHAR,
  message VARCHAR NOT NULL,
  metadata JSONB,
  "createdAt" TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_events_created ON audit_events ("createdAt" DESC);

CREATE TABLE IF NOT EXISTS keenetic_setup_requests (
  id SERIAL PRIMARY KEY,
  "userId" INTEGER NOT NULL,
  "vpnClientId" INTEGER,
  "serviceCode" VARCHAR NOT NULL,
  "routerLogin" VARCHAR NOT NULL DEFAULT 'admin',
  "encryptedPassword" TEXT NOT NULL,
  status VARCHAR NOT NULL DEFAULT 'pending',
  "customerComment" TEXT,
  "adminComment" TEXT,
  "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_keenetic_setup_requests_user ON keenetic_setup_requests ("userId");

INSERT INTO plans (name, price, "durationDays")
SELECT '1 месяц', 299, 30
WHERE NOT EXISTS (SELECT 1 FROM plans);
INSERT INTO plans (name, price, "durationDays")
SELECT '3 месяца', 799, 90
WHERE NOT EXISTS (SELECT 1 FROM plans WHERE "durationDays" = 90);
INSERT INTO plans (name, price, "durationDays")
SELECT '1 год', 2490, 365
WHERE NOT EXISTS (SELECT 1 FROM plans WHERE "durationDays" = 365);
