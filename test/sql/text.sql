
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

CREATE TABLE IF NOT EXISTS test (
  i   integer PRIMARY KEY,
  s   text NOT NULL DEFAULT ''
);

INSERT INTO test
VALUES (1, 'simple text'),
       (2, E'text with "quoted" text'),
       (3, E'newlines\nand\r\ncarriage returns'),
       (4, E'quoted text with\n"newline"');

CREATE VIEW changedata AS
SELECT data FROM pg_logical_slot_get_changes('json', NULL, NULL);

END;

--- Displays only generated JSON, no replication slot metadata, and omits
--- transaction IDs (which would confuse the testing framework because they
--- vary from run to run).
SELECT * FROM json.changedata;

SELECT 'deleted logical replication slot'
  FROM pg_drop_replication_slot('json');

DROP SCHEMA json CASCADE;
