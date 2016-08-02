#!/bin/sh
set -e

cat <<-EOF >> $PGDATA/postgresql.conf
max_replication_slots = 1
max_wal_senders = 1
wal_level = logical
EOF

cat <<-EOF >> $PGDATA/pg_hba.conf
local replication all trust
EOF

gosu postgres pg_ctl -D "$PGDATA" -m fast -w restart

make -e PGUSER=postgres test
