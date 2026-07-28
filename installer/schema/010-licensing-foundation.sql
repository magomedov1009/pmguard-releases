BEGIN;

CREATE TABLE IF NOT EXISTS organizations (
  id SERIAL PRIMARY KEY,
  name VARCHAR NOT NULL,
  slug VARCHAR NOT NULL UNIQUE,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS licenses (
  id SERIAL PRIMARY KEY,
  "organizationId" INTEGER NOT NULL UNIQUE REFERENCES organizations(id) ON DELETE CASCADE,
  status VARCHAR NOT NULL DEFAULT 'active',
  "expiresAt" TIMESTAMPTZ NULL,
  "maxAdmins" INTEGER NOT NULL DEFAULT 2,
  "maxDevices" INTEGER NOT NULL DEFAULT 3,
  "maxPanels" INTEGER NOT NULL DEFAULT 1,
  "maxClients" INTEGER NOT NULL DEFAULT 100,
  "sessionVersion" INTEGER NOT NULL DEFAULT 1,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT licenses_status_check CHECK (status IN ('active', 'suspended', 'expired')),
  CONSTRAINT licenses_limits_check CHECK (
    "maxAdmins" > 0 AND "maxDevices" > 0 AND "maxPanels" > 0 AND "maxClients" > 0
  )
);

CREATE TABLE IF NOT EXISTS organization_admins (
  id SERIAL PRIMARY KEY,
  "organizationId" INTEGER NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  "telegramId" VARCHAR NOT NULL,
  role VARCHAR NOT NULL DEFAULT 'admin',
  active BOOLEAN NOT NULL DEFAULT TRUE,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE ("organizationId", "telegramId"),
  CONSTRAINT organization_admins_role_check CHECK (role IN ('owner', 'admin', 'support'))
);

CREATE INDEX IF NOT EXISTS organization_admins_telegram_idx
  ON organization_admins ("telegramId");

CREATE TABLE IF NOT EXISTS admin_devices (
  id SERIAL PRIMARY KEY,
  "organizationAdminId" INTEGER NOT NULL REFERENCES organization_admins(id) ON DELETE CASCADE,
  "deviceHash" VARCHAR NOT NULL,
  "displayName" VARCHAR NULL,
  approved BOOLEAN NOT NULL DEFAULT FALSE,
  "approvedAt" TIMESTAMPTZ NULL,
  "revokedAt" TIMESTAMPTZ NULL,
  "lastSeenAt" TIMESTAMPTZ NULL,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE ("organizationAdminId", "deviceHash")
);

CREATE TABLE IF NOT EXISTS xui_panels (
  id SERIAL PRIMARY KEY,
  "organizationId" INTEGER NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name VARCHAR NOT NULL,
  "baseUrl" VARCHAR NOT NULL,
  "encryptedApiToken" TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  "isDefault" BOOLEAN NOT NULL DEFAULT FALSE,
  "defaultInboundId" INTEGER NULL,
  "connectionStatus" VARCHAR NOT NULL DEFAULT 'unknown',
  "lastCheckedAt" TIMESTAMPTZ NULL,
  "lastError" TEXT NULL,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT xui_panels_status_check CHECK (
    "connectionStatus" IN ('unknown', 'online', 'offline')
  )
);

CREATE INDEX IF NOT EXISTS xui_panels_organization_idx
  ON xui_panels ("organizationId");

COMMIT;
