BEGIN;

INSERT INTO organizations (name, slug, active)
VALUES ('PMGuard Primary', 'pmguard-primary', TRUE)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO licenses (
  "organizationId", status, "expiresAt", "maxAdmins", "maxDevices",
  "maxPanels", "maxClients", "sessionVersion"
)
SELECT id, 'active', NULL, 10, 20, 20, 100000, 1
FROM organizations
WHERE slug = 'pmguard-primary'
ON CONFLICT ("organizationId") DO NOTHING;

ALTER TABLE vpn_clients
  ADD COLUMN IF NOT EXISTS "panelId" INTEGER NULL REFERENCES xui_panels(id) ON DELETE RESTRICT;

DO $$
DECLARE constraint_name TEXT;
BEGIN
  SELECT con.conname INTO constraint_name
  FROM pg_constraint con
  JOIN pg_class rel ON rel.oid = con.conrelid
  WHERE rel.relname = 'vpn_clients'
    AND con.contype = 'u'
    AND (
      SELECT array_agg(att.attname ORDER BY keys.ordinality)
      FROM unnest(con.conkey) WITH ORDINALITY AS keys(attnum, ordinality)
      JOIN pg_attribute att
        ON att.attrelid = con.conrelid AND att.attnum = keys.attnum
    ) = ARRAY['xuiId']::name[];
  IF constraint_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE vpn_clients DROP CONSTRAINT %I', constraint_name);
  END IF;
END $$;

DROP INDEX IF EXISTS vpn_clients_legacy_xui_unique;
DROP INDEX IF EXISTS vpn_clients_panel_xui_unique;
CREATE UNIQUE INDEX vpn_clients_legacy_xui_unique
  ON vpn_clients ("xuiId")
  WHERE "panelId" IS NULL;
CREATE UNIQUE INDEX vpn_clients_panel_xui_unique
  ON vpn_clients ("panelId", "xuiId")
  WHERE "panelId" IS NOT NULL;

COMMIT;
