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
