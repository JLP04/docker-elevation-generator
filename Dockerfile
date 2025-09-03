FROM debian:latest AS build

LABEL name="elevation-generator"
LABEL org.opencontainers.image.authors="jlp04"

RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

ARG TARGETARCH
ARG TARGETVARIANT

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=cache-apt-$TARGETARCH-$TARGETVARIANT \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=lib-apt-$TARGETARCH-$TARGETVARIANT \
    apt update && apt dist-upgrade -y && apt --no-install-recommends install -y ca-certificates

RUN sed -i 's/http/https/g' /etc/apt/sources.list.d/*

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=cache-apt-$TARGETARCH-$TARGETVARIANT \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=lib-apt-$TARGETARCH-$TARGETVARIANT \
    apt-get update && apt --no-install-recommends install -y git sudo wget && sudo apt autoclean

RUN mkdir -p /flightgear/script

WORKDIR /flightgear/script

ADD --link https://gitlab.com/flightgear/fgmeta/-/archive/next/fgmeta-next.tar.gz /dev/null

RUN git clone -c http.postBuffer=104857600 https://gitlab.com/flightgear/fgmeta.git

WORKDIR /flightgear/script/fgmeta

RUN git pull

RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

COPY --link <<"EOF" /etc/apt/apt.conf.d/01overrides
    APT::Install-Recommends "0";
    APT::Get::Assume-Yes "true";

EOF

RUN useradd --no-log-init -r -u 999 -g sudo user

USER user:sudo

WORKDIR /flightgear/script/dnc-managed

RUN mkdir -p /flightgear/script/dnc-managed/flightgear/scripts/python

ARG DEBIAN_FRONTEND=noninteractive

ADD --link https://github.com/c-ares/c-ares.git#v1.34 /dev/null

ADD --link https://git.code.sf.net/p/libplib/code.git#master /dev/null

ARG branch_end=2024.1

ADD --link https://gitlab.com/flightgear/simgear/-/archive/release/${branch_end}/simgear-release-${branch_end}.tar.gz /dev/null

ADD --link https://gitlab.com/flightgear/flightgear/-/archive/release/${branch_end}/flightgear-release-${branch_end}.tar.gz /dev/null

ADD --link https://gitlab.com/flightgear/fgdata/-/archive/release/${branch_end}/fgdata-release-${branch_end}.tar.gz /dev/null

ADD --link https://gitlab.com/flightgear/openscenegraph/-/archive/release/2024-build/openscenegraph-release-2024-build.tar.gz /dev/null

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=cache-apt-$TARGETARCH-$TARGETVARIANT \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=lib-apt-$TARGETARCH-$TARGETVARIANT \
    --mount=type=cache,target=/flightgear/script/dnc-managed,sharing=private,id=dnc-managed-$TARGETARCH-$TARGETVARIANT,uid=999 \
    /flightgear/script/fgmeta/download_and_compile.sh -s --non-interactive -b Release --cmake-args=OSG='-DCMAKE_POLICY_DEFAULT_CMP0072=OLD -DOPENGL_PROFILE=GLCORE -DOSG_GL1_AVAILABLE=OFF -DOSG_GL2_AVAILABLE=ON -DOSG_GL3_AVAILABLE=OFF -DOpenGL_GL_PREFERENCE=LEGACY' \
    CARES \
    PLIB \
    SIMGEAR \
    FGFS \
    DATA \
    OSG || /flightgear/script/fgmeta/download_and_compile.sh -s --non-interactive -b Release --cmake-args=OSG='-DCMAKE_POLICY_DEFAULT_CMP0072=OLD -DOPENGL_PROFILE=GLCORE -DOSG_GL1_AVAILABLE=OFF -DOSG_GL2_AVAILABLE=ON -DOSG_GL3_AVAILABLE=OFF -DOpenGL_GL_PREFERENCE=LEGACY' \
    CARES \
    PLIB \
    SIMGEAR \
    FGFS \
    DATA \
    OSG
    
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=cache-apt-$TARGETARCH-$TARGETVARIANT \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=lib-apt-$TARGETARCH-$TARGETVARIANT \
    --mount=type=cache,target=/flightgear/script/dnc-managed,sharing=private,id=dnc-managed-$TARGETARCH-$TARGETVARIANT,uid=999 \
    /flightgear/script/fgmeta/download_and_compile.sh -s --non-interactive -b Release --reset-origin-url --cmake-args=OSG='-DCMAKE_POLICY_DEFAULT_CMP0072=OLD -DOPENGL_PROFILE=GLCORE -DOSG_GL1_AVAILABLE=OFF -DOSG_GL2_AVAILABLE=ON -DOSG_GL3_AVAILABLE=OFF -DOpenGL_GL_PREFERENCE=LEGACY' \
    CARES \
    PLIB \
    SIMGEAR \
    FGFS \
    DATA \
    OSG || /flightgear/script/fgmeta/download_and_compile.sh -s --non-interactive -b Release --reset-origin-url --cmake-args=OSG='-DCMAKE_POLICY_DEFAULT_CMP0072=OLD -DOPENGL_PROFILE=GLCORE -DOSG_GL1_AVAILABLE=OFF -DOSG_GL2_AVAILABLE=ON -DOSG_GL3_AVAILABLE=OFF -DOpenGL_GL_PREFERENCE=LEGACY' \
    CARES \
    PLIB \
    SIMGEAR \
    FGFS \
    DATA \
    OSG && sudo cp --preserve=all -R /flightgear/script/dnc-managed/install /tmp/install && sudo cp --preserve=all -R /flightgear/script/dnc-managed/flightgear/scripts/python/TerraSync /tmp/TerraSync

RUN sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN sudo rm /etc/apt/apt.conf.d/01overrides

WORKDIR /

ENV ATC_PIE_VERSION=1.9.1

RUN sudo wget https://sourceforge.net/projects/atc-pie/files/ATC-pie-$ATC_PIE_VERSION.tar.gz

RUN sudo tar xzf ATC-pie-$ATC_PIE_VERSION.tar.gz

RUN sudo rm /ATC-pie-$ATC_PIE_VERSION.tar.gz

RUN sudo chown -R user:sudo ATC-pie-$ATC_PIE_VERSION

COPY --link <<"EOF" /generate_elevation.sh
#!/bin/bash

    export ROUNDED_TOP=$(python3 -c \
"if (float($1) < 0):
    print(round((float($1) + 0.5)))
else:
    print(round((float($1) + 0.5)))")
    export ROUNDED_BOTTOM=$(python3 -c \
"if (float($3) < 0):
    print(round((float($3) - 0.5)))
else:
    print(round((float($3) - 0.5)))")
    export ROUNDED_LEFT=$(python3 -c \
"if (float($2) < 0):
    print(round((float($2) - 0.5)))
else:
    print(round((float($2) - 0.5)))")
    export ROUNDED_RIGHT=$(python3 -c \
"if (float($4) < 0):
    print(round((float($4) + 0.5)))
else:
    print(round((float($4) + 0.5)))")
    pushd /flightgear/script/dnc-managed/flightgear/scripts/python/TerraSync/
    ./terrasync.py -t ~/.fgfs/TerraSync/ --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://de1mirror.flightgear.org/ts/
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://de1mirror.flightgear.org/ts/ --only-subdir Airports
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://de1mirror.flightgear.org/ts/ --only-subdir Models
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://de1mirror.flightgear.org/ts/ --only-subdir Objects
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://de1mirror.flightgear.org/ts/ --only-subdir Terrain
    ./terrasync.py -t ~/.fgfs/TerraSync/ --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://de1mirror.flightgear.org/o2c/ --only-subdir osm2city
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://de1mirror.flightgear.org/o2c/ --only-subdir Buildings
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://de1mirror.flightgear.org/o2c/ --only-subdir Details
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://de1mirror.flightgear.org/o2c/ --only-subdir Pylons
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://de1mirror.flightgear.org/o2c/ --only-subdir Roads
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://de1mirror.flightgear.org/o2c/ --only-subdir Trees
    ./terrasync.py -t ~/.fgfs/TerraSync/ --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://terrasync.eti.pg.gda.pl/ts/
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://terrasync.eti.pg.gda.pl/ts/ --only-subdir Airports
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://terrasync.eti.pg.gda.pl/ts/ --only-subdir Models
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://terrasync.eti.pg.gda.pl/ts/ --only-subdir Objects
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://terrasync.eti.pg.gda.pl/ts/ --only-subdir Terrain
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://terrasync.eti.pg.gda.pl/o2c/ --only-subdir Buildings
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://terrasync.eti.pg.gda.pl/o2c/ --only-subdir Details
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://terrasync.eti.pg.gda.pl/o2c/ --only-subdir Pylons
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://terrasync.eti.pg.gda.pl/o2c/ --only-subdir Roads
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://terrasync.eti.pg.gda.pl/o2c/ --only-subdir Trees
    ./terrasync.py -t ~/.fgfs/TerraSync/ --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://us1mirror.flightgear.org/terrasync/ws2/
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://us1mirror.flightgear.org/terrasync/ws2/ --only-subdir Airports
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://us1mirror.flightgear.org/terrasync/ws2/ --only-subdir Models
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://us1mirror.flightgear.org/terrasync/ws2/ --only-subdir Objects
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://us1mirror.flightgear.org/terrasync/ws2/ --only-subdir Terrain
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://us1mirror.flightgear.org/terrasync/osm2city/ --only-subdir Buildings
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://us1mirror.flightgear.org/terrasync/osm2city/ --only-subdir Details
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://us1mirror.flightgear.org/terrasync/osm2city/ --only-subdir Pylons
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://us1mirror.flightgear.org/terrasync/osm2city/ --only-subdir Roads
    ./terrasync.py -t ~/.fgfs/TerraSync/ -r --top $ROUNDED_TOP --bottom $ROUNDED_BOTTOM --left $ROUNDED_LEFT --right $ROUNDED_RIGHT --report -u https://us1mirror.flightgear.org/terrasync/osm2city/ --only-subdir Trees

    popd

    pushd /ATC-pie-${ATC_PIE_VERSION}

    LD_LIBRARY_PATH=/flightgear/script/dnc-managed/install/openscenegraph/lib ./mkElevMap.py $1,$2 $3,$4 61 -- /flightgear/script/dnc-managed/install/flightgear/bin/fgelev

    mv OUTPUT/auto.elev OUTPUT/$5.elev

    pushd OUTPUT

    croc send $5.elev

    popd

    popd

EOF

FROM debian:latest AS build-go

ENV CROC_VERSION=10.2.4

ENV GO_VERSION=1.24

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt --no-install-recommends install -y golang-$GO_VERSION-go git ca-certificates && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

ADD --link https://github.com/schollz/croc.git#v${CROC_VERSION} /croc-v$CROC_VERSION

WORKDIR /croc-v$CROC_VERSION

ENV CGO_ENABLED=0

ENV LDFLAGS='-extldflags "-static"'

ARG TARGETARCH
ARG TARGETVARIANT

RUN --mount=type=cache,target=/root/.cache/go-build,id=cache-go-$TARGETARCH-$TARGETVARIANT /usr/lib/go-$GO_VERSION/bin/go build -ldflags "$LDFLAGS" -o croc

RUN rm -rf /root/.cache/go-build/*

RUN tar -czvf croc_v${CROC_VERSION}_Linux-unknown.tar.gz croc LICENSE

RUN sha256sum *.tar.gz > croc_v${CROC_VERSION}_checksums.txt

FROM debian:latest AS run

ENV ATC_PIE_VERSION=1.9.1

ENV CROC_VERSION=10.2.4

COPY --from=build /tmp/TerraSync /flightgear/script/dnc-managed/flightgear/scripts/python/TerraSync

COPY --from=build /tmp/install /flightgear/script/dnc-managed/install

COPY --from=build /ATC-pie-$ATC_PIE_VERSION /ATC-pie-$ATC_PIE_VERSION

COPY --from=build /generate_elevation.sh /generate_elevation.sh

COPY --from=build-go /croc-v$CROC_VERSION/croc_v${CROC_VERSION}_Linux-unknown.tar.gz /v$CROC_VERSION/

COPY --from=build-go /croc-v$CROC_VERSION/croc_v${CROC_VERSION}_checksums.txt /v$CROC_VERSION/

RUN chmod +x ./generate_elevation.sh

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt --no-install-recommends install -y curl ca-certificates python3 python-is-python3 python3-pyqt5 libopengl0 && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN set -o pipefail && curl https://getcroc.schollz.com | bash || curl https://getcroc.schollz.com | sed 's^croc_base_url="https://github.com/schollz/croc/releases/download"^croc_base_url="file:///"^g' | bash

RUN useradd --no-log-init -r -m -u 999 -g sudo user

USER user:sudo

RUN mkdir -p ~/.fgfs/TerraSync

VOLUME ["/home/user/.fgfs/TerraSync"]

WORKDIR /ATC-pie-$ATC_PIE_VERSION

ENTRYPOINT ["/generate_elevation.sh"]