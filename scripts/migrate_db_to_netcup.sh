#!/usr/bin/env bash
# Move cvcraft_production from the AWS Postgres container to the netcup one.
#
#   ./scripts/migrate_db_to_netcup.sh <NETCUP_IP> [--go]
#
# Without --go it only dumps and reports sizes/counts, touching nothing on
# netcup. With --go it restores and verifies.
#
# Only cvcraft_production is moved. The cache/queue/cable databases are
# derived — Solid Cache is a cache, Solid Queue is unused (active_job adapter
# is sidekiq), Solid Cable retains one day of messages — and `db:prepare`
# recreates all three on first boot.
set -euo pipefail

NETCUP_IP="${1:?usage: $0 <NETCUP_IP> [--go]}"
GO="${2:-}"

AWS_HOST="ubuntu@13.217.233.99"
AWS_KEY="/Users/nasserfq/Downloads/seera/seeraai.pem"
AWS_PG="cvcraft-trends-db"
NEW_HOST="root@${NETCUP_IP}"
NEW_KEY="$HOME/.ssh/cvcraft_netcup"
NEW_PG="cvcraft-db"
DB="cvcraft_production"
DUMP_DIR="$HOME/cvcraft-dumps"   # outside the repo: these hold user PII
mkdir -p "$DUMP_DIR"
DUMP="$DUMP_DIR/cvcraft_production_$(date +%Y%m%d%H%M).dump"

aws_sql() { ssh -i "$AWS_KEY" "$AWS_HOST" "docker exec -i $AWS_PG psql -U cvcraft -d $DB -tAc \"$1\""; }
new_sql() { ssh -i "$NEW_KEY" "$NEW_HOST" "docker exec -i $NEW_PG psql -U cvcraft -d $DB -tAc \"$1\""; }

counts() { # $1 = sql runner
  for t in users resumes work_experiences skills educations certifications \
           languages cv_generations cv_analyses cv_imports linkedin_imports \
           ai_translations otp_verifications coupons coupon_redemptions; do
    printf "%-22s %s\n" "$t" "$($1 "select count(*) from $t")"
  done
}

echo "==> source: table sizes"
ssh -i "$AWS_KEY" "$AWS_HOST" "docker exec -i $AWS_PG psql -U cvcraft -d $DB -c \"
  select relname, pg_size_pretty(pg_total_relation_size(c.oid)) as size
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'
  order by pg_total_relation_size(c.oid) desc limit 10\""

echo "==> source: row counts"
counts aws_sql | tee /tmp/counts.before

echo "==> dumping to $DUMP (custom format, compressed)"
ssh -i "$AWS_KEY" "$AWS_HOST" "docker exec -i $AWS_PG pg_dump -U cvcraft -Fc $DB" > "$DUMP"
ls -lh "$DUMP"

if [ "$GO" != "--go" ]; then
  echo
  echo "Dump only. Re-run with --go to restore into $NETCUP_IP."
  exit 0
fi

echo "==> restoring into $NETCUP_IP:$NEW_PG"
# --clean so a half-finished earlier attempt doesn't collide. The target db
# itself is created by the accessory's POSTGRES_DB.
ssh -i "$NEW_KEY" "$NEW_HOST" "docker exec -i $NEW_PG pg_restore -U cvcraft -d $DB --clean --if-exists --no-owner --no-acl" < "$DUMP"

echo "==> target: row counts"
counts new_sql | tee /tmp/counts.after

echo "==> diff"
if diff -u /tmp/counts.before /tmp/counts.after; then
  echo "row counts match."
else
  echo "ROW COUNTS DIFFER — do not flip DNS." >&2
  exit 1
fi
