# This Dockerfile extends the Examples-ORM testing image in order to
# install specific dependencies required for ActiveRecord tests.

FROM us-east1-docker.pkg.dev/crl-ci-images/cockroach/example-orms-builder:20200413-1918

# Native dependencies for libxml-ruby and sqlite3.
RUN apt-get --allow-releaseinfo-change update -y && apt-get install -y \
  libxslt-dev \
  libxml2-dev \
  libsqlite3-dev \
  rbenv \
  && rm -rf /var/lib/apt/lists/*

RUN rm -rf ~/ruby-build; git clone https://github.com/sstephenson/ruby-build.git ~/ruby-build; sh ~/ruby-build/install.sh
