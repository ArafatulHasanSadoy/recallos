-- RecallOS schema v10, exactly as a fresh install creates it.
-- Frozen 2026-10-08, before v11, so the v11 migration is tested from
-- the real starting point. Never edit by hand. FTS5 shadow tables are
-- left out: the virtual table creates its own.

CREATE TABLE "attributes" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "subject_type" TEXT NOT NULL, "subject_id" INTEGER NOT NULL, "key" TEXT NOT NULL, "value" TEXT NOT NULL, "source" TEXT NOT NULL, "confidence" REAL NULL);

CREATE TABLE "capability_profiles" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "subject_type" TEXT NOT NULL, "subject_id" INTEGER NOT NULL, "canonical_en" TEXT NOT NULL, "services_json" TEXT NULL, "categories_json" TEXT NULL, "model" TEXT NOT NULL);

CREATE TABLE "card_fields" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "card_id" INTEGER NOT NULL REFERENCES cards (id) ON DELETE CASCADE, "field_key" TEXT NOT NULL, "value" TEXT NOT NULL, "normalized_value" TEXT NULL, "source" TEXT NOT NULL, "confidence" REAL NULL, "verified_by_user" INTEGER NOT NULL DEFAULT 0 CHECK ("verified_by_user" IN (0, 1)), "validation_issue" TEXT NULL, "value_kind" TEXT NOT NULL DEFAULT 'text', "region_rect" TEXT NULL, "side" TEXT NOT NULL DEFAULT 'front');

CREATE TABLE "cards" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "type" TEXT NOT NULL DEFAULT 'unknown', "image_path" TEXT NOT NULL, "back_image_path" TEXT NULL, "thumb_path" TEXT NULL, "raw_ocr_text" TEXT NULL, "back_ocr_text" TEXT NULL, "ocr_engine" TEXT NULL, "ocr_confidence" REAL NULL, "extraction_status" TEXT NOT NULL DEFAULT 'pending', "captured_at" INTEGER NOT NULL, "person_id" INTEGER NULL REFERENCES people (id), "org_id" INTEGER NULL REFERENCES organizations (id), "role_id" INTEGER NULL REFERENCES roles (id));

CREATE TABLE "contact_points" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "owner_type" TEXT NOT NULL, "owner_id" INTEGER NOT NULL, "kind" TEXT NOT NULL, "value" TEXT NOT NULL, "normalized_value" TEXT NULL, "label" TEXT NULL, "role_id" INTEGER NULL REFERENCES roles (id), "source_card_id" INTEGER NULL REFERENCES cards (id) ON DELETE CASCADE, "source" TEXT NOT NULL, "is_active" INTEGER NOT NULL DEFAULT 1 CHECK ("is_active" IN (0, 1)));

CREATE TABLE "duplicate_candidates" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "subject_type" TEXT NOT NULL, "a_id" INTEGER NOT NULL, "b_id" INTEGER NOT NULL, "score" REAL NOT NULL, "signals_json" TEXT NULL, "status" TEXT NOT NULL DEFAULT 'pending');

CREATE TABLE "embeddings" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "subject_type" TEXT NOT NULL, "subject_id" INTEGER NOT NULL, "vector" BLOB NOT NULL, "dim" INTEGER NOT NULL, "model" TEXT NOT NULL);

CREATE TABLE "encounters" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "card_id" INTEGER NOT NULL REFERENCES cards (id) ON DELETE CASCADE, "met_on" INTEGER NULL, "place" TEXT NULL, "origin" TEXT NOT NULL DEFAULT 'user');

CREATE TABLE "extraction_attempts" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "card_id" INTEGER NOT NULL REFERENCES cards (id) ON DELETE CASCADE, "engine" TEXT NOT NULL, "started_at" INTEGER NOT NULL, "duration_ms" INTEGER NOT NULL, "status" TEXT NOT NULL, "fields_found" INTEGER NOT NULL DEFAULT 0, "error_code" TEXT NULL, "error_detail" TEXT NULL);

CREATE TABLE "important_dates" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "card_id" INTEGER NOT NULL REFERENCES cards (id) ON DELETE CASCADE, "kind" TEXT NOT NULL, "title" TEXT NOT NULL, "due_on" INTEGER NOT NULL, "status" TEXT NOT NULL DEFAULT 'open', "completed_at" INTEGER NULL);

CREATE TABLE "interactions" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "subject_type" TEXT NOT NULL, "subject_id" INTEGER NOT NULL, "kind" TEXT NOT NULL, "detail" TEXT NULL, "occurred_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)));

CREATE TABLE "notes" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "subject_type" TEXT NOT NULL, "subject_id" INTEGER NOT NULL, "body" TEXT NULL, "audio_path" TEXT NULL, "transcript" TEXT NULL, "language" TEXT NULL);

CREATE TABLE "ocr_blocks" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "card_id" INTEGER NOT NULL REFERENCES cards (id) ON DELETE CASCADE, "text" TEXT NOT NULL, "rect" TEXT NOT NULL, "confidence" REAL NOT NULL, "script" TEXT NOT NULL, "engine" TEXT NULL, "assigned_field_key" TEXT NULL, "field_id" INTEGER NULL REFERENCES card_fields (id) ON DELETE SET NULL, "order_index" INTEGER NOT NULL DEFAULT 0, "side" TEXT NOT NULL DEFAULT 'front');

CREATE TABLE "org_branches" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "org_id" INTEGER NOT NULL REFERENCES organizations (id), "address" TEXT NULL, "lat" REAL NULL, "lng" REAL NULL, "phone" TEXT NULL, "is_primary" INTEGER NOT NULL DEFAULT 0 CHECK ("is_primary" IN (0, 1)));

CREATE TABLE "organizations" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, "category" TEXT NULL, "website" TEXT NULL, "website_domain" TEXT NULL, "merged_into_id" INTEGER NULL);

CREATE TABLE "people" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "display_name" TEXT NOT NULL, "photo_path" TEXT NULL, "relationship" TEXT NULL, "trust_score" REAL NOT NULL DEFAULT 0.5, "merged_into_id" INTEGER NULL);

CREATE TABLE "profile_fields" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "profile_id" INTEGER NOT NULL REFERENCES profiles (id) ON DELETE CASCADE, "field_key" TEXT NOT NULL, "value" TEXT NOT NULL, "normalized_value" TEXT NULL, "label" TEXT NULL, "order_index" INTEGER NOT NULL DEFAULT 0);

CREATE TABLE "profiles" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "label" TEXT NULL, "is_default" INTEGER NOT NULL DEFAULT 0 CHECK ("is_default" IN (0, 1)), "photo_path" TEXT NULL, "tagline" TEXT NULL);

CREATE TABLE "ranking_weights" ("key" TEXT NOT NULL, "value" REAL NOT NULL, PRIMARY KEY ("key"));

CREATE TABLE "reminders" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "important_date_id" INTEGER NOT NULL REFERENCES important_dates (id) ON DELETE CASCADE, "remind_at" INTEGER NOT NULL, "status" TEXT NOT NULL DEFAULT 'scheduled', "snooze_count" INTEGER NOT NULL DEFAULT 0);

CREATE TABLE "roles" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "person_id" INTEGER NOT NULL REFERENCES people (id), "org_id" INTEGER NOT NULL REFERENCES organizations (id), "title" TEXT NULL, "is_current" INTEGER NOT NULL DEFAULT 1 CHECK ("is_current" IN (0, 1)), "start_date" INTEGER NULL, "end_date" INTEGER NULL);

CREATE TABLE "search_feedback" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "query_id" INTEGER NOT NULL REFERENCES search_queries (id) ON DELETE CASCADE, "subject_type" TEXT NOT NULL, "subject_id" INTEGER NOT NULL, "verdict" TEXT NOT NULL, "created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)));

CREATE VIRTUAL TABLE search_index USING fts5(
  subject_type UNINDEXED,
  subject_id   UNINDEXED,
  card_text,
  note_text,
  canonical_en,
  tags,
  met_text,
  tokenize = "unicode61 remove_diacritics 2"
);

CREATE TABLE "search_queries" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "raw" TEXT NOT NULL, "normalized_json" TEXT NULL, "lang" TEXT NULL, "created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)));

CREATE TABLE "settings" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, PRIMARY KEY ("key"));

CREATE TABLE "subject_tags" ("tag_id" INTEGER NOT NULL REFERENCES tags (id) ON DELETE CASCADE, "subject_type" TEXT NOT NULL, "subject_id" INTEGER NOT NULL, PRIMARY KEY ("tag_id", "subject_type", "subject_id"));

CREATE TABLE "tags" ("created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted_at" INTEGER NULL, "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL UNIQUE);

CREATE INDEX idx_contact_points_card ON contact_points(source_card_id);

CREATE INDEX idx_contact_points_lookup ON contact_points(normalized_value, kind);

CREATE INDEX idx_contact_points_owner ON contact_points(owner_type, owner_id);

CREATE INDEX idx_encounters_card ON encounters(card_id);

CREATE INDEX idx_important_dates_card ON important_dates(card_id);

CREATE INDEX idx_important_dates_due ON important_dates(status, due_on);

CREATE INDEX idx_organizations_domain ON organizations(website_domain);

CREATE UNIQUE INDEX idx_profiles_default ON profiles(is_default) WHERE is_default = 1;

CREATE INDEX idx_reminders_date ON reminders(important_date_id);
