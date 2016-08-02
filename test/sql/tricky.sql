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

CREATE TABLE IF NOT EXISTS tab1 (
  i   integer PRIMARY KEY,
  h   hstore NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS tab2 (
  i   integer PRIMARY KEY,
  j   integer NOT NULL DEFAULT 0
);

INSERT INTO tab1 (i) VALUES (1);
INSERT INTO tab2 (i) VALUES (1);

INSERT INTO tab1 (i) VALUES (2);
INSERT INTO tab2 (i) VALUES (2);

INSERT INTO tab1 (i) VALUES (3);
INSERT INTO tab2 (i) VALUES (3);

INSERT INTO tab1 (i) VALUES (4);
INSERT INTO tab2 (i) VALUES (4);

CREATE VIEW changedata AS
SELECT data FROM pg_logical_slot_get_changes('json', NULL, NULL);

END;

BEGIN;
SET LOCAL search_path TO json, public;
UPDATE tab1 SET h = hstore('i', i::text)||hstore('2i', (2*i)::text);
DELETE FROM tab1 WHERE i % 2 = 1;
DELETE FROM tab2 WHERE i % 2 = 1;
END;

SELECT * FROM json.changedata;

SELECT 'deleted logical replication slot'
  FROM pg_drop_replication_slot('json');

DROP SCHEMA json CASCADE;
