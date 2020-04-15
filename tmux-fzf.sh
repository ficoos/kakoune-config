#!/usr/bin/sh
ppid=$$
args=${@@Q}
status_fifo=$(mktemp -u)
mkfifo $status_fifo
exec 3<>$status_fifo
rm -f $status_fifo
tmux split-pane -p 30 -- sh -c "fzf ${args} >/proc/$ppid/fd/1 </proc/$ppid/fd/0; echo \$? >>/proc/$ppid/fd/3"
sleep 0.2
read l <&3
exit $l
