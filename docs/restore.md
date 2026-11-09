# Restore the database

Two kinds of dumps live on the server (both on the same disk as the database, so they protect against bad
migrations and mistakes, not against losing the server):

| Kind | Where | Kept |
|---|---|---|
| Nightly | `/root/cvcraft-db-backup/backups/{last,daily,weekly,monthly}/` (`.sql.gz`) | 7 daily, 4 weekly, 6 monthly |
| Before each Deploy or Rollback | `/root/cvcraft-db-backup/pre-deploy/` (`.dump`, custom format) | newest 5 |

Nightly dumps only exist once `bin/kamal accessory boot db-backup` has been run.

## Steps

Run these from the Mac, one at a time.

1. Log in to the server:

   ```
   ssh -i ~/.ssh/cvcraft_netcup root@159.195.9.248
   ```

2. Pick the dump (newest first):

   ```
   ls -lt /root/cvcraft-db-backup/pre-deploy/ /root/cvcraft-db-backup/backups/last/
   ```

3. Stop the app and the worker so nothing writes during the restore (exit the server first, run on the Mac in `~/Downloads/cvcrft`):

   ```
   bin/kamal app stop
   ```

4. Back on the server, keep a copy of the current state, then restore (replace `FILE` with the dump path):

   ```
   docker exec cvcraft-db pg_dump -U cvcraft -Fc cvcraft_production > /root/cvcraft-db-backup/before-restore-$(date +%F-%H%M).dump
   docker exec cvcraft-db psql -U cvcraft -d postgres -c 'DROP DATABASE cvcraft_production WITH (FORCE)'
   docker exec cvcraft-db psql -U cvcraft -d postgres -c 'CREATE DATABASE cvcraft_production OWNER cvcraft'
   ```

   Then, for a nightly `.sql.gz`:

   ```
   gunzip -c FILE | docker exec -i cvcraft-db psql -U cvcraft -d cvcraft_production
   ```

   or for a pre-deploy `.dump`:

   ```
   docker exec -i cvcraft-db pg_restore -U cvcraft -d cvcraft_production --no-owner < FILE
   ```

5. Start the app again (Mac):

   ```
   bin/kamal app boot
   ```

6. Check `https://cvcrft.com/up` answers `{"status":"ok"...}` and sign in once.

If the code also has to go back, run **Actions › Rollback** first (it does not undo migrations, which is
why the restore comes with it).

## Practice

Restore the newest nightly dump into a scratch database once a quarter, so the steps are known to work:

```
docker exec cvcraft-db psql -U cvcraft -d postgres -c 'CREATE DATABASE restore_check'
gunzip -c FILE | docker exec -i cvcraft-db psql -q -U cvcraft -d restore_check
docker exec cvcraft-db psql -U cvcraft -d restore_check -c 'SELECT count(*) FROM users'
docker exec cvcraft-db psql -U cvcraft -d postgres -c 'DROP DATABASE restore_check'
```
