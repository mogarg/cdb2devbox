#!/bin/zsh

set -x

# sets up cluster stuff for comdb2 
# - creats a host directory in the current location as a volumes
# folder. creates subdirectory for the master copy and directories
# for the replica copies.
#
# volumes/master-copy
#     |--/node1-dbs
#     |--/node2-dbs
#     |--/node3-dbs
#      and so on...
#
# emits a cluster nodes node1 node2 node3 to the lrl file in the master copy container 


HOMEDIR="/home/heisengarg"
DBS="$HOMEDIR/dbs" # dbs volume location in the container
DBSMNTVOL="comdb2-dbs" # host volume name that mounts to the DBS dir
IMAGE="heisengarg/devbox"
VERSION="latest"
VOLUMES="$HOMEDIR/volumes"
LOCALVOLUMES="$(pwd)/volumes"

if [[ "$#" -ne 2 ]]; then
    echo "Usage: $0 <dbname> <hosts>" >&2
    exit 1
fi

DBNAME="$1"

if ! DOCKER="$(command -v docker)"; then
    echo "docker not found"
    exit 1
fi

if ! COPYCOMDB2="$(PATH=$PATH:/opt/bb/bin command -v copycomdb2)"; then
    echo "docker not found"
    exit 1
fi


IFS="," read -rA hosts <<< "$2"

$DOCKER run --rm --mount type=volume,source="$DBSMNTVOL",target="$DBS" \
    $IMAGE:$VERSION -e DBNAME="$DBNAME" -e HOSTS="$2" clust "$DBNAME" "$HOSTS"

for host in ${hosts[@]}; do
    mkdir -p "$$LOCALVOLUMES/$host-dbs"
done

$DOCKER container create --name dummy \
    --mount type=volume,source="$DBSMNTVOL",target="$DBS" \
    --mount type=volume,source="$LOCALVOLUMES",target="$VOLUMES" "$IMAGE:$VERSION" 

$DOCKER cp dummy:"$HOMEDIR/dbs/$DBNAME" ./volumes/master 
$DOCKER rm dummy 1>&2 2>/dev/null

#for host in ${hosts[@]}; do
#    $COPYCOMDB2 -m "$VOLUMES/master/$DBNAME/$DBNAME.lrl" "$VOLUMES/master/$DBNAME/" "$VOLUMES/$host-dbs"
#done

