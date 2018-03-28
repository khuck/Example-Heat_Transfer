#!/bin/bash

# cleanup
rm -rf staged.bp* conf ht.out sw.out sosd.* tau-metrics.*
killall -9 mpirun dataspaces_server python sosd

set -e

export SOS_CMD_PORT=22500
export SOS_WORK=`pwd`
export SOS_EVPATH_MEETUP=`pwd`

gdb --args ./sosd -l 0 -a 1 -k 0 -r aggregator -w ${SOS_WORK}

