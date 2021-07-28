ARG VARIANT="latest"
ARG IMAGE="heisengarg/devbox"
ARG USER=heisengarg

FROM quay.io/iovisor/bpftrace:latest as bpfsource

# --- perf ----
FROM ${IMAGE}:${VARIANT} as perfsource

USER root

RUN apt-get update &&  apt-get -y install --no-install-recommends \
    libelf-dev libbfd-dev libcap-dev libnuma-dev \
    libunwind-dev libzstd-dev libssl-dev \
    systemtap-sdt-dev libslang2-dev libperl-dev \
    libiberty-dev libbabeltrace-dev \
    libdw-dev \
    wget bison flex xz-utils

RUN  wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.25.tar.xz \
     && tar -xf linux-5.10.25.tar.xz \
     && cd linux-5.10.25/tools/perf \
     && make -j 16 -C . \
     && make install

# --- end perf --

FROM ${IMAGE}:${VARIANT}

WORKDIR /home/heisengarg/comdb2

ENV PATH $PATH:/opt/bb/bin

USER root

RUN apt-get update && apt-get -y install --no-install-recommends \
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
    ninja-build

# For development work
RUN sudo apt-get update && sudo apt-get -y install --no-install-recommends \
    gawk                 \
    linux-tools-common   \
    valgrind             \
    cscope               \
    figlet               \
    iputils-ping         \
    net-tools            \
    sshpass

# For perf
RUN sudo apt-get update && sudo apt-get -y install --no-install-recommends \
    libslang2-dev libnuma-dev

COPY --from=bpfsource /usr/bin/bpftrace /usr/bin/bpftrace
COPY --from=perfsource /home/heisengarg/linux-5.10.25/tools/perf/perf /usr/bin/perf

USER heisengarg

RUN sudo mkdir -p $HOME/.ssh && sudo chown -R $(whoami) $HOME/.ssh \
    && sudo chmod 755 $HOME/.ssh && sudo service ssh restart

EXPOSE 5105
COPY ./entrypoint.sh /usr/local/bin/
