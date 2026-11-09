# Fails unsafe migrations (removing or renaming a column, a non-concurrent
# index, a blocking column change...) with an explanation of the safe way to
# write them. Old code keeps running against the new schema while a deploy
# switches over, so a migration must work with both versions of the code.

# Migrations up to this version ran before the gem was added and are not checked.
StrongMigrations.start_after = 2026_11_09_000300

# Production runs Postgres 17 (config/deploy.yml), so checks that depend on
# the server version match production even where dev/test run an older one.
StrongMigrations.target_version = 17
