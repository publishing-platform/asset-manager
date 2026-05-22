ARG ruby_version=3.4
ARG clam_version=1.5.2
ARG base_image=ghcr.io/publishing-platform/publishing-platform-ruby-base:$ruby_version
ARG builder_image=ghcr.io/publishing-platform/publishing-platform-ruby-builder:$ruby_version

FROM $builder_image AS clam_builder
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ARG clam_version
ARG clam_url_prefix=https://github.com/Cisco-Talos/clamav/releases/download
ARG clam_url=$clam_url_prefix/clamav-${clam_version}/clamav-${clam_version}.tar.gz

WORKDIR /src
RUN curl -SLfso - "$clam_url" | tar -zxf - --strip-components=1

WORKDIR /src/build

# install required tools and clamav dependencies
RUN install_packages \
      gcc make pkg-config python3 python3-pip python3-pytest valgrind cmake curl sudo \
      check libbz2-dev libcurl4-openssl-dev libjson-c-dev libmilter-dev \
      libncurses5-dev libpcre2-dev libssl-dev libxml2-dev zlib1g-dev


RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
      && \
      . $HOME/.cargo/env \
      && \
      rustup update \
      && \
      cmake .. \
        -D CLAMAV_USER=app \
        -D CLAMAV_GROUP=app \
        -D CMAKE_BUILD_TYPE="Release" \
        -D DATABASE_DIRECTORY="/var/lib/clamav" \
        -D ENABLE_CLAMONACC=OFF \
        -D ENABLE_JSON_SHARED=OFF \
        -D ENABLE_MAN_PAGES=OFF \
        -D ENABLE_MILTER=OFF

RUN make DESTDIR=/clamav -j$(nproc) install


FROM $builder_image AS app_builder

WORKDIR $APP_HOME
COPY Gemfile* .ruby-version ./
RUN bundle install
COPY . .
RUN bootsnap precompile --gemfile .


FROM $base_image

ENV PUBLISHING_PLATFORM_APP_NAME=asset-manager

# install clamav dependencies
RUN install_packages \
      check libbz2-dev libcurl4-openssl-dev libjson-c-dev libmilter-dev \
      libncurses5-dev libpcre2-dev libssl-dev libxml2-dev zlib1g-dev

# create directory for database
RUN mkdir -p /var/lib/clamav ; \
    chown app:app /var/lib/clamav

COPY --from=clam_builder /clamav /

# Crude smoke test and print library versions.
RUN echo -n clamd:\ ; clamd --version -c /dev/null ; \
    ldd $(which clamd) ; \
    echo -n clamdscan:\ ; clamdscan --version -c /dev/null ; \
    ldd $(which clamdscan)

WORKDIR $APP_HOME
COPY --from=app_builder $BUNDLE_PATH $BUNDLE_PATH
COPY --from=app_builder $BOOTSNAP_CACHE_DIR $BOOTSNAP_CACHE_DIR
COPY --from=app_builder $APP_HOME .

USER app
CMD ["puma"]

