-- COURTNEY HOSTING Database Schema
-- Run this once on your PostgreSQL database before starting the server

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Sessions (auth)
CREATE TABLE IF NOT EXISTS "sessions" (
  "sid" varchar PRIMARY KEY,
  "sess" jsonb NOT NULL,
  "expire" timestamp NOT NULL
);
CREATE INDEX IF NOT EXISTS "IDX_session_expire" ON "sessions" ("expire");

-- Users
CREATE TABLE IF NOT EXISTS "users" (
  "id" varchar PRIMARY KEY DEFAULT gen_random_uuid(),
  "replit_id" varchar UNIQUE,
  "github_id" varchar UNIQUE,
  "google_id" varchar UNIQUE,
  "email" varchar UNIQUE,
  "password_hash" varchar,
  "email_verified" boolean NOT NULL DEFAULT true,
  "warning_sent" boolean NOT NULL DEFAULT false,
  "first_name" varchar,
  "last_name" varchar,
  "profile_image_url" varchar,
  "coins" integer NOT NULL DEFAULT 100,
  "last_active_at" timestamptz NOT NULL DEFAULT now(),
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now()
);

-- Email verifications
CREATE TABLE IF NOT EXISTS "email_verifications" (
  "id" varchar PRIMARY KEY DEFAULT gen_random_uuid(),
  "user_id" varchar NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  "email" varchar NOT NULL,
  "code" varchar(6) NOT NULL,
  "attempts" integer NOT NULL DEFAULT 0,
  "expires_at" timestamptz NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now()
);

-- Bots
CREATE TABLE IF NOT EXISTS "bots" (
  "id" varchar PRIMARY KEY DEFAULT gen_random_uuid(),
  "user_id" varchar NOT NULL,
  "name" varchar NOT NULL,
  "session_id" varchar NOT NULL,
  "bot_type_id" varchar,
  "pterodactyl_server_id" varchar,
  "coins_per_month" integer NOT NULL DEFAULT 900,
  "status" text NOT NULL DEFAULT 'stopped',
  "expires_at" timestamptz,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now()
);

-- Bot settings (admin-controlled catalog overrides)
CREATE TABLE IF NOT EXISTS "bot_settings" (
  "bot_type_id" varchar PRIMARY KEY,
  "disabled" boolean NOT NULL DEFAULT false,
  "disable_message" text,
  "session_link_override" varchar,
  "github_repo_override" varchar,
  "pterodactyl_server_id_override" varchar,
  "notes" text,
  "session_env_key" varchar DEFAULT 'SESSION_ID',
  "session_format" text,
  "env_template" text,
  "auto_setup" boolean NOT NULL DEFAULT false,
  "config_file_path" varchar DEFAULT '/home/container/.env',
  "config_file_format" varchar DEFAULT 'env',
  -- Auto-provisioning overrides (per bot type; fall back to global settings)
  "egg_id" integer,
  "docker_image" varchar,
  "startup_command" text,
  "memory_limit" integer,
  "disk_limit" integer,
  "cpu_limit" integer,
  "location_ids" varchar,
  "pterodactyl_user_id" integer,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now()
);

-- Migrate existing bot_settings tables that predate the provisioning columns
ALTER TABLE "bot_settings" ADD COLUMN IF NOT EXISTS "egg_id" integer;
ALTER TABLE "bot_settings" ADD COLUMN IF NOT EXISTS "docker_image" varchar;
ALTER TABLE "bot_settings" ADD COLUMN IF NOT EXISTS "startup_command" text;
ALTER TABLE "bot_settings" ADD COLUMN IF NOT EXISTS "memory_limit" integer;
ALTER TABLE "bot_settings" ADD COLUMN IF NOT EXISTS "disk_limit" integer;
ALTER TABLE "bot_settings" ADD COLUMN IF NOT EXISTS "cpu_limit" integer;
ALTER TABLE "bot_settings" ADD COLUMN IF NOT EXISTS "location_ids" varchar;
ALTER TABLE "bot_settings" ADD COLUMN IF NOT EXISTS "pterodactyl_user_id" integer;

-- Transactions (M-Pesa/Payflow payments)
CREATE TABLE IF NOT EXISTS "transactions" (
  "id" varchar PRIMARY KEY DEFAULT gen_random_uuid(),
  "user_id" varchar NOT NULL,
  "checkout_request_id" varchar,
  "phone" varchar NOT NULL,
  "kes_amount" integer NOT NULL,
  "coins_amount" integer NOT NULL,
  "package_name" varchar NOT NULL,
  "status" varchar NOT NULL DEFAULT 'pending',
  "transaction_code" varchar,
  "reference" varchar NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now()
);

-- Notifications
CREATE TABLE IF NOT EXISTS "notifications" (
  "id" varchar PRIMARY KEY DEFAULT gen_random_uuid(),
  "user_id" varchar NOT NULL,
  "type" varchar(20) NOT NULL DEFAULT 'info',
  "title" varchar(255) NOT NULL,
  "message" text NOT NULL,
  "link" varchar(500),
  "read" boolean NOT NULL DEFAULT false,
  "created_at" timestamptz NOT NULL DEFAULT now()
);

-- App settings (key/value store)
CREATE TABLE IF NOT EXISTS "settings" (
  "key" varchar(100) PRIMARY KEY,
  "value" text NOT NULL,
  "updated_at" timestamptz NOT NULL DEFAULT now()
);

-- Partner applications
CREATE TABLE IF NOT EXISTS "partner_applications" (
  "id" varchar PRIMARY KEY DEFAULT gen_random_uuid(),
  "type" varchar(20) NOT NULL,
  "name" varchar(255) NOT NULL,
  "email" varchar(255) NOT NULL,
  "whatsapp_number" varchar(30),
  "github_repo" varchar(500),
  "bot_name" varchar(255),
  "bot_description" text,
  "experience" text,
  "message" text,
  "status" varchar(20) NOT NULL DEFAULT 'pending',
  "created_at" timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- COURTNEY HOSTING: SUBDOMAIN MARKETPLACE
-- ============================================================

-- Subdomain pricing tiers (admin-controlled)
CREATE TABLE IF NOT EXISTS "subdomain_pricing" (
  "id" varchar PRIMARY KEY DEFAULT gen_random_uuid(),
  "tier" varchar(20) NOT NULL DEFAULT 'regular',
  "name" varchar(100) NOT NULL,
  "kes_per_year" integer NOT NULL,
  "coins_per_year" integer NOT NULL DEFAULT 0,
  "description" text,
  "active" boolean NOT NULL DEFAULT true,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now()
);

-- Premium subdomain names (admin-curated list)
CREATE TABLE IF NOT EXISTS "premium_subdomains" (
  "name" varchar(100) PRIMARY KEY,
  "kes_per_year" integer NOT NULL DEFAULT 500,
  "created_at" timestamptz NOT NULL DEFAULT now()
);

-- Purchased subdomains
CREATE TABLE IF NOT EXISTS "subdomains" (
  "id" varchar PRIMARY KEY DEFAULT gen_random_uuid(),
  "user_id" varchar NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  "subdomain" varchar(100) NOT NULL,
  "full_domain" varchar(200) NOT NULL,
  "tier" varchar(20) NOT NULL DEFAULT 'regular',
  "status" varchar(20) NOT NULL DEFAULT 'active',
  "cloudflare_record_id" varchar(100),
  "cloudflare_zone_id" varchar(100),
  "ip_address" varchar(45),
  "expires_at" timestamptz NOT NULL,
  "renewal_reminder_sent" boolean NOT NULL DEFAULT false,
  "suspended_at" timestamptz,
  "suspended_reason" text,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT "subdomains_subdomain_unique" UNIQUE ("subdomain")
);
CREATE INDEX IF NOT EXISTS "idx_subdomains_user_id" ON "subdomains" ("user_id");
CREATE INDEX IF NOT EXISTS "idx_subdomains_expires_at" ON "subdomains" ("expires_at");
CREATE INDEX IF NOT EXISTS "idx_subdomains_status" ON "subdomains" ("status");

-- DNS records per subdomain
CREATE TABLE IF NOT EXISTS "subdomain_dns_records" (
  "id" varchar PRIMARY KEY DEFAULT gen_random_uuid(),
  "subdomain_id" varchar NOT NULL REFERENCES "subdomains"("id") ON DELETE CASCADE,
  "cloudflare_record_id" varchar(100),
  "type" varchar(10) NOT NULL,
  "name" varchar(255) NOT NULL,
  "content" varchar(1000) NOT NULL,
  "ttl" integer NOT NULL DEFAULT 1,
  "priority" integer,
  "proxied" boolean NOT NULL DEFAULT false,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS "idx_dns_subdomain_id" ON "subdomain_dns_records" ("subdomain_id");

-- Subdomain payment history
CREATE TABLE IF NOT EXISTS "subdomain_payments" (
  "id" varchar PRIMARY KEY DEFAULT gen_random_uuid(),
  "user_id" varchar NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  "subdomain_id" varchar REFERENCES "subdomains"("id") ON DELETE SET NULL,
  "subdomain_name" varchar(200) NOT NULL,
  "type" varchar(20) NOT NULL DEFAULT 'purchase',
  "method" varchar(20) NOT NULL DEFAULT 'wallet',
  "kes_amount" integer NOT NULL,
  "coins_used" integer NOT NULL DEFAULT 0,
  "promo_code" varchar(50),
  "discount_kes" integer NOT NULL DEFAULT 0,
  "status" varchar(20) NOT NULL DEFAULT 'completed',
  "mpesa_checkout_id" varchar,
  "mpesa_code" varchar,
  "created_at" timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS "idx_subdomain_payments_user_id" ON "subdomain_payments" ("user_id");

-- Cloudflare audit log
CREATE TABLE IF NOT EXISTS "cloudflare_logs" (
  "id" varchar PRIMARY KEY DEFAULT gen_random_uuid(),
  "user_id" varchar REFERENCES "users"("id") ON DELETE SET NULL,
  "subdomain_id" varchar REFERENCES "subdomains"("id") ON DELETE SET NULL,
  "action" varchar(50) NOT NULL,
  "status" varchar(20) NOT NULL DEFAULT 'success',
  "details" jsonb,
  "created_at" timestamptz NOT NULL DEFAULT now()
);

-- Subdomain to bot connections
CREATE TABLE IF NOT EXISTS "subdomain_bot_connections" (
  "id" varchar PRIMARY KEY DEFAULT gen_random_uuid(),
  "subdomain_id" varchar NOT NULL REFERENCES "subdomains"("id") ON DELETE CASCADE,
  "bot_id" varchar NOT NULL REFERENCES "bots"("id") ON DELETE CASCADE,
  "user_id" varchar NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT "uq_subdomain_bot" UNIQUE ("subdomain_id", "bot_id")
);

-- Promo codes
CREATE TABLE IF NOT EXISTS "promo_codes" (
  "id" varchar PRIMARY KEY DEFAULT gen_random_uuid(),
  "code" varchar(50) NOT NULL,
  "description" text,
  "discount_type" varchar(20) NOT NULL DEFAULT 'percent',
  "discount_value" integer NOT NULL,
  "max_uses" integer,
  "used_count" integer NOT NULL DEFAULT 0,
  "valid_from" timestamptz NOT NULL DEFAULT now(),
  "valid_until" timestamptz,
  "active" boolean NOT NULL DEFAULT true,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT "uq_promo_code" UNIQUE ("code")
);

-- Default pricing data (idempotent)
INSERT INTO "subdomain_pricing" ("id", "tier", "name", "kes_per_year", "coins_per_year", "description")
VALUES
  (gen_random_uuid(), 'regular', 'Regular Subdomain', 100, 1000, 'Any available name under courtneytech.xyz — 1 year'),
  (gen_random_uuid(), 'premium', 'Premium Subdomain', 500, 5000, 'Short, brandable, or high-demand names — 1 year')
ON CONFLICT DO NOTHING;
