BEGIN;

ALTER TABLE licenses
  ADD COLUMN IF NOT EXISTS "maxInstallations" INTEGER NOT NULL DEFAULT 1;

CREATE TABLE IF NOT EXISTS installations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "organizationId" INTEGER NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  fingerprint VARCHAR NOT NULL,
  "activationSecretHash" VARCHAR NOT NULL,
  status VARCHAR NOT NULL DEFAULT 'active',
  hostname VARCHAR NULL,
  "publicIp" VARCHAR NULL,
  version VARCHAR NULL,
  "lastSeenAt" TIMESTAMPTZ NULL,
  "revokedAt" TIMESTAMPTZ NULL,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE ("organizationId", fingerprint)
);

CREATE INDEX IF NOT EXISTS installations_organization_idx
  ON installations ("organizationId");

CREATE TABLE IF NOT EXISTS installation_tokens (
  id SERIAL PRIMARY KEY,
  "organizationId" INTEGER NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  "tokenHash" VARCHAR NOT NULL UNIQUE,
  "expiresAt" TIMESTAMPTZ NOT NULL,
  "usedAt" TIMESTAMPTZ NULL,
  "installationId" UUID NULL REFERENCES installations(id) ON DELETE SET NULL,
  "revokedAt" TIMESTAMPTZ NULL,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS installation_tokens_organization_idx
  ON installation_tokens ("organizationId");

COMMIT;
