FROM postgres:9.5

COPY . ./

RUN set -x \
  && apt-get update \
  && apt-get install -y --no-install-recommends gcc make pgxnclient postgresql-server-dev-$PG_MAJOR=$PG_VERSION \
  && make all install \
  && mv test.sh /docker-entrypoint-initdb.d \
  && /docker-entrypoint.sh postgres --version
