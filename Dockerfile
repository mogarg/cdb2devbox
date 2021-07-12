ARG VARIANT="latest"
ARG IMAGE="heisengarg/devbox"
ARG USER="heisengarg"

FROM quay.io/iovisor/bpftrace:latest as bpfsource

ARG VARIANT="latest"
ARG IMAGE="heisengarg/devbox"

FROM ${IMAGE}:${VARIANT} as perfsource

USER root

RUN apt-get update &&  apt-get -y install --no-install-recommends \
    wget bison flex xz-utils

RUN  wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.25.tar.xz \
     && tar -xf linux-5.10.25.tar.xz \
     && cd linux-5.10.25/tools/perf \
     && make -j 8 -C . \
     && make install

FROM ${IMAGE}:${VARIANT}

WORKDIR /home/${USER}/comdb2

ENV PATH $PATH:/opt/bb/bin

RUN sudo apt-get update && sudo apt-get -y install --no-install-recommends \ 
    bison \
    build-essential      \
    cmake                \
    flex                 \
    libevent-dev         \
    liblz4-dev           \
    libprotobuf-c-dev    \
    libreadline-dev      \
    libsqlite3-dev       \
    libssl-dev           \
    libunwind-dev        \
    ncurses-dev          \
    protobuf-c-compiler  \
    tcl                  \
    uuid-dev             \
    zlib1g-dev           \
    dialog               \
    jq tcl-dev           \
    ninja-build          \
    gawk                 \
    linux-tools-common   \
    valgrind             \
    cscope               \
    figlet               \
    iputils-ping         \
    net-tools

COPY --from=bpfsource /usr/bin/bpftrace /usr/bin/bpftrace
COPY --from=perfsource /home/heisengarg/linux-5.10.25/tools/perf/perf /usr/bin/perf

EXPOSE 5105 
COPY ./entrypoint.sh /usr/local/bin/
