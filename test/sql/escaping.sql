\set ECHO none
SET client_min_messages TO error;
\t on
\x off
SELECT 'created logical replication slot'
  FROM pg_create_logical_replication_slot('json', 'json-output');

BEGIN;

CREATE SCHEMA IF NOT EXISTS json;
SET LOCAL search_path TO json, public;
CREATE EXTENSION IF NOT EXISTS hstore;

CREATE TABLE IF NOT EXISTS "****" (
  i   integer PRIMARY KEY
);

INSERT INTO "****" (i) SELECT i FROM generate_series(1, 8) AS i;

CREATE VIEW changedata AS
SELECT data FROM pg_logical_slot_get_changes('json', NULL, NULL);

END;

SELECT * FROM json.changedata;

SELECT 'deleted logical replication slot';

DROP SCHEMA json CASCADE;
