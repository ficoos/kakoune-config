#!/usr/bin/sh
ppid=$$
args=${@@P}
status_fifo=$(mktemp -u)
mkfifo $status_fifo
exec 3<>$status_fifo
rm -f $status_fifo
tmux split-pane -p 30 sh -c "fzf ${args} >/proc/$ppid/fd/1 </proc/$ppid/fd/0; echo \$? >>/proc/$ppid/fd/3"
read l <&3
exit $l
