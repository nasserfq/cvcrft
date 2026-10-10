# AWS → netcup migration runbook

Kamal stays, the Dockerfile stays, Rails 8 + Postgres stay. What changes is the
host, and two things AWS was quietly doing for us.

## What AWS was actually providing

| AWS thing | Replacement |
|---|---|
| EC2 `13.217.233.99` | netcup VPS (`NETCUP_IP` in `config/deploy.yml`) |
| Security group blocking :5432 | nothing — see "Firewall" below |
| SES (email) | unchanged; SES works from any host |

Nothing else was AWS. ActiveStorage is local Disk (`config/storage.yml`) and
nothing is attached, generated PDFs live base64 in `cv_generations.metadata`,
and the AI calls go to Azure OpenAI.

## Before cutover

1. **Rotate both leaked credentials.** The old Postgres password sat in
   `config/deploy.yml`, which is in git history, and the Docker Hub PAT is in
   `.env`. Generate a new DB password and a new PAT, then export them in your
   shell — `.kamal/secrets` now reads both from the environment:
   ```bash
   export CVCRAFT_DATABASE_PASSWORD='<new>' KAMAL_REGISTRY_PASSWORD='<new PAT>'
   ```
2. Fill in `NETCUP_IP` in `config/deploy.yml` (3 places) and add your SSH key
   to the VPS as `root`.
3. Lower the DNS TTL for `cvcrft.com` to 60s a day ahead.

## Provision

```bash
kamal setup   # installs docker, boots db + redis accessories, first deploy
```

`kamal setup` will fail the first boot if DNS still points at AWS — kamal-proxy
needs `cvcrft.com` resolving to the new box to get a Let's Encrypt cert. Deploy
first, flip DNS, then `kamal deploy` again.

## Firewall — the netcup-specific bit

EC2's security group was the only thing keeping Postgres off the internet. A
netcup VPS ships with no firewall and a public IPv4+IPv6. The `port: 5432`
line is gone from the db accessory for that reason, but close the box anyway:

```bash
ssh root@NETCUP_IP 'ufw default deny incoming && ufw allow 22,80,443/tcp && ufw --force enable'
```

Note `ufw` does not filter Docker's published ports (Docker writes its own
iptables rules ahead of ufw's chain) — that is why the fix is not publishing
5432 in the first place, not the firewall.

## Move the data

Both stores, in this order, with the app stopped on AWS.

```bash
# 1. Postgres — all four databases (primary, cache, queue, cable)
ssh ubuntu@13.217.233.99 \
  'docker exec cvcraft-trends-db pg_dumpall -U cvcraft' | gzip > cvcraft.sql.gz

gunzip -c cvcraft.sql.gz | ssh root@NETCUP_IP \
  'docker exec -i cvcraft-db psql -U cvcraft -d postgres'
```

pg_dumpall from 14 restores into 17 fine. Check the row counts for `users`,
`resumes` and `cv_generations` on both sides before flipping DNS.

**2. Redis — not just a cache.** `CouponRedemptionStore`
(`app/services/coupon_redemption_store.rb`) keeps every coupon redemption in
redis db 1, and the old accessory had no volume, so that data exists only in
RAM on the EC2 box. Drain Sidekiq first (in-flight jobs share db 1 with the
coupon keys), then:

```bash
ssh ubuntu@13.217.233.99 'docker exec cvcraft-trends-redis redis-cli save'
ssh ubuntu@13.217.233.99 'docker cp cvcraft-trends-redis:/data/dump.rdb -' > redis-dump.tar

kamal accessory stop redis
# untar dump.rdb into the new redis volume, then:
kamal accessory boot redis
```

The new redis accessory runs with `--appendonly yes` and a `data:` volume, so
redemptions survive a restart from here on.

## Cutover

1. `kamal deploy` to netcup, verify `/up` responds with a `Host: cvcrft.com` header.
2. Point the `cvcrft.com` A record (and AAAA, if you use the VPS's IPv6) at the VPS.
3. `kamal deploy` again so kamal-proxy gets its cert.
4. Smoke test: sign-up OTP email, a CV generation end to end, a PDF download,
   a coupon redemption.
5. Keep the EC2 box stopped (not terminated) for a week.

## If you want the AWS account closed too

Only SES is left. Swap `AmazonSesService` for SMTP — netcup's own mail, or
Postmark/Brevo — and the `aws-sdk-ses` gem goes with it. One file, four call
sites (`send_otp_email_job`, `batch_email_service`, and the two load-test
jobs). Do it after the move, not during.
