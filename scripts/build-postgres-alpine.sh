#!/bin/bash
set -ex

CWD=$(dirname "$0")

DOCKER_OPTS=
POSTGIS_VERSION=
LITE_OPT=false
WITH_TOOLKIT=true

while getopts "v:i:g:o:lt" opt; do
    case $opt in
    v) PG_VERSION=$OPTARG ;;
    i) IMG_NAME=$OPTARG ;;
    g) POSTGIS_VERSION=$OPTARG ;;
    o) DOCKER_OPTS=$OPTARG ;;
    l) LITE_OPT=true ;;
    t) WITH_TOOLKIT=false ;;
    \?) exit 1 ;;
    esac
done

case "${PG_VERSION}" in
  *12*)
    pgrx_flag="pg12"
    ;;
  *13*)
    pgrx_flag="pg13"
    ;;
  *14*)
    pgrx_flag="pg14"
    ;;
  *15*)
    pgrx_flag="pg15"
    ;;
  *16*)
    pgrx_flag="pg16"
    ;;
esac

if [ -z "$PG_VERSION" ] ; then
  echo "Postgres version parameter is required!" && exit 1;
fi
if [ -z "$IMG_NAME" ] ; then
  echo "Docker image parameter is required!" && exit 1;
fi
if echo "$PG_VERSION" | grep -q '^9\.' && [ "$LITE_OPT" = true ] ; then
  echo "Lite option is supported only for PostgreSQL 10 or later!" && exit 1;
fi

E2FS_ENABLED=$(echo "$PG_VERSION" | grep -qv '^9\.[0-3]\.' && echo true || echo false);
ICU_ENABLED=$(echo "$PG_VERSION" | grep -qv '^9\.' && [ "$LITE_OPT" != true ] && echo true || echo false);

TRG_DIR=$PWD/bundle
mkdir -p $TRG_DIR

docker run -i --rm -v ${TRG_DIR}:/usr/local/pg-dist \
-e PG_VERSION=$PG_VERSION \
-e POSTGIS_VERSION=$POSTGIS_VERSION \
-e E2FS_ENABLED=$E2FS_ENABLED \
-e ICU_ENABLED=$ICU_ENABLED \
-e PROJ_VERSION=6.0.0 \
-e PROJ_DATUMGRID_VERSION=1.8 \
-e GEOS_VERSION=3.7.2 \
-e GDAL_VERSION=2.4.1 \
-e WITH_TOOLKIT=$WITH_TOOLKIT \
-e pgrx_flag=$pgrx_flag \
$DOCKER_OPTS $IMG_NAME /bin/sh -ex -c 'echo "Starting building postgres binaries" \
    && apk add --no-cache \
        coreutils \
        ca-certificates \
        wget \
        tar \
        xz \
        gcc \
        make \
        libc-dev \
        icu-dev \
        linux-headers \
        util-linux-dev \
        libxml2-dev \
        libxslt-dev \
        openssl-dev \
        zlib-dev \
        perl-dev \
        python3-dev \
        tcl-dev \
        chrpath \
        flex \
        bison \
        curl \
        git \
        clang \
        pkgconfig \
        readline-dev \
        libxml2-utils \
        ccache \
        g++ \
        libgcrypt \
        musl-dev \
        build-base \
        musl \
        musl-dev \
        lld \
        libressl-dev \
        libffi-dev \
        tree \
        \
    && if [ "$E2FS_ENABLED" = false ]; then \
        wget -O uuid.tar.gz "https://www.mirrorservice.org/sites/ftp.ossp.org/pkg/lib/uuid/uuid-1.6.2.tar.gz" \
        && mkdir -p /usr/src/ossp-uuid \
        && tar -xf uuid.tar.gz -C /usr/src/ossp-uuid --strip-components 1 \
        && cd /usr/src/ossp-uuid \
        && wget -O config.guess "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=b8ee5f79949d1d40e8820a774d813660e1be52d3" \
        && wget -O config.sub "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=b8ee5f79949d1d40e8820a774d813660e1be52d3" \
        && ./configure --prefix=/usr/local \
        && make -j$(nproc) \
        && make install \
        && cp --no-dereference /usr/local/lib/libuuid.* /lib; \
       fi \
       \
    && wget -O postgresql.tar.bz2 "https://ftp.postgresql.org/pub/source/v$PG_VERSION/postgresql-$PG_VERSION.tar.bz2" \
    && mkdir -p /usr/src/postgresql \
    && tar -xf postgresql.tar.bz2 -C /usr/src/postgresql --strip-components 1 \
    && cd /usr/src/postgresql \
    && wget -O config/config.guess "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=b8ee5f79949d1d40e8820a774d813660e1be52d3" \
    && wget -O config/config.sub "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=b8ee5f79949d1d40e8820a774d813660e1be52d3" \
    && ./configure \
        CFLAGS="-Os" \
        PYTHON=/usr/bin/python3 \
        --prefix=/usr/local/pg-build \
        --enable-integer-datetimes \
        --enable-thread-safety \
        $([ "$E2FS_ENABLED" = true ] && echo "--with-uuid=e2fs" || echo "--with-ossp-uuid") \
        --with-gnu-ld \
        --with-includes=/usr/local/include \
        --with-libraries=/usr/local/lib \
        $([ "$ICU_ENABLED" = true ] && echo "--with-icu") \
        --with-libxml \
        --with-libxslt \
        --with-openssl \
        --with-perl \
        --with-python \
        --with-tcl \
        --without-readline \
    && make -j$(nproc) world-bin \
    && make install-world-bin \
    && make -C contrib install \
    \
    && if [ -n "$POSTGIS_VERSION" ]; then \
      apk add --no-cache curl g++ json-c-dev linux-headers sqlite sqlite-dev sqlite-libs unzip \
      && mkdir -p /usr/src/proj \
        && curl -sL "https://download.osgeo.org/proj/proj-$PROJ_VERSION.tar.gz" | tar -xzf - -C /usr/src/proj --strip-components 1 \
        && cd /usr/src/proj \
        && curl -sL "https://download.osgeo.org/proj/proj-datumgrid-$PROJ_DATUMGRID_VERSION.zip" > proj-datumgrid.zip \
        && unzip -o proj-datumgrid.zip -d data\
        && curl -sL "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=b8ee5f79949d1d40e8820a774d813660e1be52d3" > config.guess \
        && curl -sL "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=b8ee5f79949d1d40e8820a774d813660e1be52d3" > config.sub \
        && ./configure --disable-static --prefix=/usr/local/pg-build \
        && make -j$(nproc) \
        && make install \
      && mkdir -p /usr/src/geos \
        && curl -sL "https://download.osgeo.org/geos/geos-$GEOS_VERSION.tar.bz2" | tar -xjf - -C /usr/src/geos --strip-components 1 \
        && cd /usr/src/geos \
        && curl -sL "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=b8ee5f79949d1d40e8820a774d813660e1be52d3" > config.guess \
        && curl -sL "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=b8ee5f79949d1d40e8820a774d813660e1be52d3" > config.sub \
        && ./configure --disable-static --prefix=/usr/local/pg-build \
        && make -j$(nproc) \
        && make install \
      && mkdir -p /usr/src/gdal \
        && curl -sL "https://download.osgeo.org/gdal/$GDAL_VERSION/gdal-$GDAL_VERSION.tar.xz" | tar -xJf - -C /usr/src/gdal --strip-components 1 \
        && cd /usr/src/gdal \
        && curl -sL "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=b8ee5f79949d1d40e8820a774d813660e1be52d3" > config.guess \
        && curl -sL "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=b8ee5f79949d1d40e8820a774d813660e1be52d3" > config.sub \
        && ./configure --disable-static --prefix=/usr/local/pg-build \
        && make -j$(nproc) \
        && make install \
      && mkdir -p /usr/src/postgis \
        && curl -sL "https://postgis.net/stuff/postgis-$POSTGIS_VERSION.tar.gz" | tar -xzf - -C /usr/src/postgis --strip-components 1 \
        && cd /usr/src/postgis \
        && curl -sL "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=b8ee5f79949d1d40e8820a774d813660e1be52d3" > config.guess \
        && curl -sL "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=b8ee5f79949d1d40e8820a774d813660e1be52d3" > config.sub \
        && ./configure \
            --prefix=/usr/local/pg-build \
            --with-pgconfig=/usr/local/pg-build/bin/pg_config \
            --with-geosconfig=/usr/local/pg-build/bin/geos-config \
            --with-projdir=/usr/local/pg-build \
            --with-gdalconfig=/usr/local/pg-build/bin/gdal-config \
        && make -j$(nproc) \
        && make install \
    ; fi \
    \
    && if [ "$WITH_TOOLKIT" = true ]; then \
      curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
      && . "$HOME/.cargo/env" \
      && export PATH="/usr/local/pg-build/bin:${PATH}" \
      && rustup target add x86_64-unknown-linux-musl \
      && RUSTFLAGS="-C target-feature=-crt-static" cargo install --version "=0.10.2" --force cargo-pgrx \
      && RUSTFLAGS="-C target-feature=-crt-static" cargo pgrx init --$pgrx_flag pg_config \
      && git clone https://github.com/timescale/timescaledb-toolkit && cd timescaledb-toolkit/extension \
      && git checkout 1.18.0 \
      && RUSTFLAGS="-C target-feature=-crt-static" cargo pgrx install --release && RUSTFLAGS="-C target-feature=-crt-static" cargo run --manifest-path ../tools/post-install/Cargo.toml -- pg_config \
    ; fi \
    \
    && cd /usr/local/pg-build \
    && cp /lib/libuuid.so.1 /lib/libz.so.1 /usr/lib/libxml2.so.2 /usr/lib/libxslt.so.1 ./lib \
    && if [ -f "/lib/libssl.so.1.1" ]; then \
      cp /lib/libssl.so.1.1 ./lib \
    ; fi \
    \
    && if [ -f "/lib/libcrypto.so.1.1" ]; then \
      cp /lib/libcrypto.so.1.1 ./lib \
    ; fi \
    \
    && if [ "$ICU_ENABLED" = true ]; then cp --no-dereference /usr/lib/libicudata.so* /usr/lib/libicuuc.so* /usr/lib/libicui18n.so* /usr/lib/libstdc++.so* /usr/lib/libgcc_s.so* ./lib; fi \
    && if [ -n "$POSTGIS_VERSION" ]; then cp --no-dereference /usr/lib/libjson-c.so* /usr/lib/libsqlite3.so* ./lib ; fi \
    && find ./bin -type f \( -name "initdb" -o -name "pg_ctl" -o -name "postgres" \) -print0 | xargs -0 -n1 chrpath -r "\$ORIGIN/../lib" \
    && tar -cJvf /usr/local/pg-dist/postgres-linux-alpine_linux.txz --hard-dereference \
        share/postgresql \
        lib \
        bin/initdb \
        bin/pg_ctl \
        bin/postgres'
