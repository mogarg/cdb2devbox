ARG VARIANT="latest"
ARG IMAGE="heisengarg/devbox"
ARG USER="heisengarg"

FROM quay.io/iovisor/bpftrace:latest as bpfsource

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
    valgrind             \
    cscope               \
    figlet               \
    iputils-ping         \
    net-tools

COPY --from=bpfsource /usr/bin/bpftrace /usr/bin/bpftrace

EXPOSE 5105 
COPY ./entrypoint.sh /usr/local/bin/
