#!/usr/local/bin/zsh

set -e

TMUX="$(command -v tmux)"
DOCKER="$(command -v docker)"

run_client() {
	# <hostname> <dbname>
	$DOCKER exec -it "$1" cdb2sql "$2"
}

open_tmux() {
	# <hostnames> <dbname>
	IFS=',' read -rA HOSTS <<<$1
	DBNAME="$2"
	TMSESS="$DBNAME-cluster"
	WINDOW="$DBNAME"
	$TMUX has-session -t "$TMSESS" 2>/dev/null && $TMUX kill-session -t "$TMSESS"
	$TMUX new -d -c "$(pwd)" -s "$TMSESS" -n "$WINDOW"
	$TMUX send-keys -t "$TMSESS:$WINDOW" "./client.sh -a -d '$2' -n ${HOSTS[1]}" Enter
	for host in "${HOSTS[@]:1}"; do
		$TMUX split-window
		$TMUX send-keys "./client.sh -a -d '$2' -n '$host'" Enter
		$TMUX select-layout tiled
	done
	open_logs "$1" "$2"
	$TMUX a -t "$TMSESS"
}

open_logs() {
	IFS=',' read -rA HOSTS <<<$1
	DBNAME="$2"
	TMSESS="$DBNAME-cluster"
	WINDOW="$DBNAME-logs"
	if $TMUX has-session -t "$TMSESS" 2>/dev/null; then
		$TMUX new-window -c "$(pwd)" -t "$TMSESS" -n "$WINDOW"
	else
		$TMUX new -d -c "$(pwd)" -s "$TMSESS" -n "$WINDOW"
	fi
	$TMUX send-keys -t "$TMSESS:$WINDOW" "$DOCKER compose logs -f comdb2-${HOSTS[1]}" Enter
	for host in "${HOSTS[@]:1}"; do
		$TMUX split-window
		$TMUX send-keys "$DOCKER compose logs -f comdb2-$host" Enter
		$TMUX select-layout tiled
	done
	$TMUX a -t "$TMSESS:$DBNAME-logs"
}

opt_attach=0
opt_logs=0
opt_db=''
opt_hosts=''

while getopts ahld:n: name; do
	case $name in
	d)
		opt_db="$OPTARG"
		;;
	n)
		opt_hosts="$OPTARG"
		;;
	a)
		opt_attach=1
		;;
	l) opt_logs=1 ;;
	h | ?)
		cat <<EOF >&2
 Usage: ./client.sh {-a | -d <database> -n <host1,host2,host3>}
     -a  run client for the given host
     -d  database name
     -n  hostnames
 Example:
     ./client.sh -a -d testdb -h host1 # runs client in host1
     ./client.sh -d testdb -h host1,host2,host3 # opens a tmux session for each host
                                         # and runs a client there
EOF
		exit 1
		;;
	esac
done
shift $(expr $OPTIND - 1)

if [ -z $opt_db ] && [ -z $opt_db ]; then
	echo "dbname and/or hostname not passed"
	$0 -h
	exit 1
fi

if [[ $opt_logs != 0 ]]; then
	open_logs $opt_hosts $opt_db
elif [[ $opt_attach != 0 ]]; then
	run_client $opt_hosts $opt_db
else
	open_tmux $opt_hosts $opt_db
fi
