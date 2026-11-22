# Pi-hole v6 (Alpine) + Unbound, built from source with a verified tarball.
ARG BASE_IMG_TAG=latest

# ---------------------------------------------------------------- build stage
FROM pihole/pihole:${BASE_IMG_TAG} AS unbound

ARG UNBOUND_VERSION=1.26.2
ARG UNBOUND_SHA256=d8ee7aa6bbb3ff1be7d9e57637d0d0ec2f18273a8efff1a0afe2c665858b96f7

WORKDIR /tmp/src

RUN set -eux; \
    apk add --no-cache \
      build-base \
      curl \
      expat-dev \
      flex \
      bison \
      fstrm-dev \
      libevent-dev \
      linux-headers \
      nghttp2-dev \
      openssl-dev \
      protobuf-c-dev; \
    curl -fsSL "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz" -o unbound.tar.gz; \
    echo "${UNBOUND_SHA256}  unbound.tar.gz" | sha256sum -c -; \
    tar xzf unbound.tar.gz; \
    cd "unbound-${UNBOUND_VERSION}"; \
    addgroup -S _unbound; \
    adduser -S -H -h /etc -g _unbound -D -G _unbound _unbound; \
    ./configure \
      --disable-dependency-tracking \
      --prefix=/opt/unbound \
      --with-pthreads \
      --with-username=_unbound \
      --with-ssl \
      --with-libevent \
      --with-libnghttp2 \
      --enable-dnstap \
      --enable-tfo-server \
      --enable-tfo-client \
      --enable-event-api \
      --enable-subnet; \
    make -j"$(nproc)"; \
    make install; \
    mv /opt/unbound/etc/unbound/unbound.conf /opt/unbound/etc/unbound/unbound.conf.example; \
    rm -rf /opt/unbound/share/man /opt/unbound/include; \
    mkdir -p /opt/unbound/defaults; \
    curl -fsSL https://www.internic.net/domain/named.root -o /opt/unbound/defaults/root.hints

# --------------------------------------------------------------- final image
FROM pihole/pihole:${BASE_IMG_TAG}

# Runtime libs only; refresh all packages to pick up Alpine security fixes.
RUN set -eux; \
    apk upgrade --no-cache; \
    apk add --no-cache \
      ca-certificates \
      drill \
      expat \
      fstrm \
      libevent \
      nghttp2-libs \
      perl \
      protobuf-c; \
    addgroup -S _unbound; \
    adduser -S -H -h /etc -g _unbound -D -G _unbound _unbound

COPY --from=unbound /opt/unbound /opt/unbound

# Default config files shipped in the image (unbound.sh copies any that are missing).
COPY data/opt/unbound/etc/unbound/ /opt/unbound/defaults/
COPY lighttpd-external.conf /etc/lighttpd/external.conf
COPY 99-edns.conf /etc/dnsmasq.d/99-edns.conf
COPY data/unbound.sh /unbound.sh
RUN chmod +x /unbound.sh

WORKDIR /opt/unbound/

LABEL maintainer="OrigamiOfficial (community fork)"

ENV FTLCONF_dns_upstreams=127.0.0.1#5335
ENV PATH=/opt/unbound/sbin:$PATH

# Pi-hole v6's start.sh ignores CMD, so wrap the entrypoint instead.
ENTRYPOINT ["/unbound.sh"]
