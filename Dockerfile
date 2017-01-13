FROM postgres:9.5

RUN set -x \
  && apt-get update \
  && apt-get install -y --no-install-recommends gcc libc-dev make pgxnclient postgresql-server-dev-$PG_MAJOR=$PG_VERSION

WORKDIR /json-output

COPY . ./

RUN set -x \
  && make all install \
  && mv test.sh /docker-entrypoint-initdb.d \
  && /docker-entrypoint.sh postgres --version
