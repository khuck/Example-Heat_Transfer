#!/bin/bash

# cleanup
rm -rf *.lock tau-metrics.*
killall -9 mpirun dataspaces_server sosd

set -e

export SOS_CMD_PORT=22500
export SOS_WORK=`pwd`
export SOS_EVPATH_MEETUP=`pwd`

sos_launch() {
    adiospath=$HOME/src/ADIOS/ADIOS-gcc/lib/python
    adiospath2=$HOME/src/ADIOS/ADIOS-gcc/lib/python2.7/site-packages
    sospath=$HOME/src/sos_flow/build
    export PATH=$PATH:$sospath/bin
    export PYTHONPATH=$sospath/bin:$sospath/lib:$PYTHONPATH:`pwd`:$adiospath2
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:`pwd`:$sospath/lib:$adiospath2:/home/khuck/install/chaos-stable/lib

    echo "Launching SOS..."
    ./sosd -l 0 -a 1 -k 0 -r aggregator -w ${SOS_WORK} >& sosd.out &
    sleep 1
    echo "Launching ADIOS trace export from SOS..."
    # LD_PRELOAD=/home/khuck/install/chaos-stable/lib/libatl.so:/home/khuck/install/chaos-stable/lib/libevpath.so python $HOME/src/sos_flow_experiments/sos_scripts/tau_trace_adios.py &
    LD_PRELOAD=/home/khuck/install/chaos-stable/lib/libatl.so:/home/khuck/install/chaos-stable/lib/libevpath.so python $HOME/src/sos_flow_experiments/sos_scripts/tau_profile_adios.py &
    sleep 1
}

sos_launch
