#!/bin/zsh

set -e

# The script runs the comdb dev container and persists
# using three directories
# comdb2-opt-bb-bin:/opt/bb/bin/
# comdb2-dbs:/home/heisengarg/dbs
# binds the comdb2 top level directory to /home/heisengarg/comdb2
#
# The binding is only relevant for building

HOMEDIR="/home/heisengarg/"
DBSDIR="$HOMEDIR/dbs/"
CLUSTVOLDIR="$HOMEDIR/volumes/" # directory to copy the database to when building a cluster
DBNAME="testdb"

build() {
	mkdir -p build && cd build &&
		cmake -GNinja -DCMAKE_BUILD_TYPE=Debug ..
	ninja && sudo ninja install
}

clean_build() {
	[[ -d build ]] && rm -rf build && mkdir build
	build
}

new_db() {
	if ! COMDB2="$(command -v comdb2)"; then
		echo "Failed to find comdb2"
		exit 1
	fi
	if [ ! -d "$DBSDIR" ]; then
		echo "The $DBSDIR doesn't exist. Forgot to mount?"
		exit 2
	fi
	# when we mount a directory, the current user
	# might not have permissions to write to the directory
	# since it is mounted with root access
	if [ -w "$DBSDIR" ]; then
		sudo chown -R $(whoami) "$DBSDIR"
	fi

	if [ -z "$1" ]; then
		echo "no dbname passed using testdb"
	else
		DBNAME="$1"
	fi

	# make a directory for logs
	sudo mkdir -p /opt/bb/var/log/cdb2 && sudo chown -R $(whoami) /opt/bb/
	$COMDB2 --create --dir "$DBSDIR/$DBNAME" "$DBNAME"

	# Add extra lrl options if we want by copying the lrl.options file
	# , and setting the $LRLFILEOPTSPATH file path
	if [ -n "$LRLFILEOPTSPATH" ]; then
		if [ -e "$LRLFILEOPTSPATH" ]; then
			echo "Appending lrl.options to "$DBNAME".lrl"
			cat "$LRLFILEOPTSPATH" >>"$DBSDIR/$DBNAME/$DBNAME.lrl"
		else
			echo "An lrl.options file path: $LRLFILEOPTSPATH given but file doesn't exist"
		fi
	fi
}

clusterize() {
	# <dbname> <hosts> <skip_copy_db=1>
	if [ -z "$1" ]; then
		echo "no dbname passed using testdb"
	else
		DBNAME="$1"
	fi

	if [ -z "$2" ]; then
		echo "No hosts passed. Pass hosts as mach1,mach2,..,machn"
		exit 1
	fi

	IFS=',' read -rA hosts <<<"$2"

	[[ ! -d "$CLUSTVOLDIR" ]] && echo "volumes directory not found. Forgot to mount?" && exit 2
	[[ ! -w "$CLUSTVOLDIR" ]] && sudo chown -R $(whoami) "$CLUSTVOLDIR"

	echo "Copying binary files to $CLUSTVOLDIR/bin"
	for file in $(ls /opt/bb/bin/); do
		if [ -x "$CLUSTVOLDIR/bin" ]; then
			[[ -n "$(diff /opt/bb/bin/$file $CLUSTVOLDIR/bin/$file)" ]] && echo "$file is changed" || echo "latest $file present"
		else
			echo "New binary $file"
		fi
	done

	[[ -d "$CLUSTVOLDIR/bin" ]] && rm -r "$CLUSTVOLDIR/bin"
	cp -R /opt/bb/bin "$CLUSTVOLDIR/bin"

	if [[ "$3" -eq "1" ]]; then
		exit 0
	fi

	if ! CPCOMDB2="$(command -v copycomdb2)"; then
		echo "Failed to find comdb2"
		exit 1
	fi

	echo "cluster nodes $(IFS=" " echo "${hosts[@]}")
" >>"$DBSDIR/$DBNAME/$DBNAME.lrl"

	for host in ${hosts[@]}; do
		echo "Copying $DBNAME from $DBSDIR/$DBNAME/$DBNAME.lrl to $CLUSTVOLDIR/$host-dbs/$DBNAME"
		$CPCOMDB2 "$DBSDIR/$DBNAME/$DBNAME.lrl" "$CLUSTVOLDIR/$host-dbs/$DBNAME"
		# Hack: I don't want the lrl dir path modified to $HOME/volumes/node1-dbs/dbname etc since
		# $HOME/volumes/node1-dbs is just a mount and this would be mounted to $HOME/dbs/dbname
		cp "$DBSDIR/$DBNAME/$DBNAME.lrl" "$CLUSTVOLDIR/$host-dbs/$DBNAME/$DBNAME.lrl"
	done
}

run_db() {
	if ! COMDB2="$(command -v comdb2)"; then
		echo "Failed to find comdb2"
		exit 1
	fi
	if [ -z "$1" ]; then
		echo "no dbname passed using testdb"
	else
		DBNAME="$1"
	fi

	if [ ! -f "$DBSDIR/$DBNAME/$DBNAME.lrl" ]; then
		echo "$DBNAME.lrl file doesn't exist. Did you build db?"
		exit 2
	fi

	# make a directory for logs
	[[ ! -d /opt/bb/var/log/cdb2 ]] && sudo mkdir -p /opt/bb/var/log/cdb2
	sudo chown -R $(whoami) /opt/bb/

	pmux -n && $COMDB2 --lrl "$DBSDIR/$DBNAME/$DBNAME.lrl" "$DBNAME"
}

copy_run_db() {
	if ! CPCOMDB2="$(command -v copycomdb2)"; then
		echo "Failed to find comdb2"
		exit 1
	fi
	if [ -z "$1" ]; then
		echo "no dbname passed using testdb"
	else
		DBNAME="$1"
	fi

	FROMHOST="$2"

	$CPCOMDB2 "$FROMHOST:$DBSDIR/$DBNAME/$DBNAME.lrl"

	run_db "$1"
}

run_client() {
	if ! CDB2SQL="$(command -v cdb2sql)"; then
		echo "Failed to find comdb2"
		exit 1
	fi
	if [ -z "$1" ]; then
		echo "no dbname passed using testdb"
	else
		DBNAME="$1"
	fi
	"$CDB2SQL" "$DBNAME"
}

case "$1" in
build)
	build
	;;
clean)
	clean_build
	;;
shell)
	figlet "$hostname"
	/bin/zsh
	;;
db)
	shift
	new_db $*
	;;
run)
	shift
	run_db $*
	;;
cprun)
	shift
	copy_run_db $*
	;;
client)
	shift
	run_client $*
	;;
clust)
	shift
	clusterize $*
	;;
clustbin)
	shift
	clusterize $* 1
	;;
*)
	exec "$@"
	;;
esac
