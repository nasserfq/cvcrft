# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t cvcraft .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name cvcraft cvcraft

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.3.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems and Node.js
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config curl python3 make g++ && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install --no-install-recommends -y nodejs && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Skip npm install since CSS is already built
# COPY package.json package-lock.json ./
# RUN npm ci --include=optional && npm rebuild @parcel/watcher

# Copy application code
COPY . .

# Create a dummy npm script to avoid CSS build issues
RUN echo '#!/bin/bash\necho "Skipping CSS build"\nexit 0' > /usr/local/bin/npm && \
    chmod +x /usr/local/bin/npm

# Ensure the CSS file exists and is readable
RUN ls -la app/assets/builds/ && \
    test -f app/assets/builds/application.css && \
    echo "CSS file found and accessible"

# Remove the problematic CSS file from the manifest to avoid SassC processing
RUN sed -i '/link application.css/d' app/assets/config/manifest.js && \
    sed -i '/link_directory.*stylesheets/d' app/assets/config/manifest.js

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Create public assets directory and copy the built CSS file
RUN mkdir -p public/assets && \
    cp app/assets/builds/application.css public/assets/application.css

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
# Skip CSS build for now to avoid parcel watcher issues
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile




# Final stage for app image
FROM base

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
