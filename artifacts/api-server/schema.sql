-- ANONYMIKETECH Database Schema
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
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now()
);

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
