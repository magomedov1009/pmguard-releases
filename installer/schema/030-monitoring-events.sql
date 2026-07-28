ALTER TABLE client_links ADD COLUMN IF NOT EXISTS "displayName" VARCHAR;

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
