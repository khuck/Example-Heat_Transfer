#!/bin/bash

# cleanup, just in case
rm -rf staged.bp* conf ht.out sw.out sosd.* tau-metrics.* *_profiles
killall -9 mpirun dataspaces_server sosd

set -e

# link executables
if [ ! -f dataspaces.conf ] ; then
    ln -s ../dataspaces.conf dataspaces.conf
fi
if [ ! -f dataspaces_server ] ; then
    ln -s /home/khuck/install/dataspaces/1.6.2/bin/dataspaces_server dataspaces_server 
fi
if [ ! -f heat_transfer_adios2 ] ; then
    ln -s ../heat_transfer_adios2 heat_transfer_adios2 
fi
if [ ! -f heat_transfer.xml ] ; then
     ln -s ../heat_transfer.xml heat_transfer.xml
fi
if [ ! -f sosd ] ; then
    ln -s /home/khuck/src/sos_flow/build/bin/sosd sosd 
fi
if [ ! -f sosd_stop ] ; then
    ln -s /home/khuck/src/sos_flow/build/bin/sosd_stop sosd_stop 
fi
if [ ! -f stage_write ] ; then
    ln -s  ../stage_write/stage_write stage_write 
fi

export SOS_CMD_PORT=22500
export SOS_WORK=`pwd`
export SOS_EVPATH_MEETUP=`pwd`
export SOS_BATCH_ENVIRONMENT=1
export SOS_IN_MEMORY_DATABASE=1

sos_launch() {
    adiospath=$HOME/src/ADIOS/ADIOS-gcc/lib/python
    adiospath2=$HOME/src/ADIOS/ADIOS-gcc/lib/python2.7/site-packages
    sospath=$HOME/src/sos_flow/build
    export PATH=$PATH:$sospath/bin
    export PYTHONPATH=$sospath/bin:$sospath/lib:$PYTHONPATH:`pwd`:$adiospath2
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:`pwd`:$sospath/lib:$adiospath2:/home/khuck/install/chaos-stable/lib

    echo "Launching SOS..."
    #/usr/local/bin/heaptrack ./sosd -l 0 -a 1 -k 0 -r aggregator -w ${SOS_WORK} >& sosd.out &
    ./sosd -l 0 -a 1 -k 0 -r aggregator -w ${SOS_WORK} >& sosd.out &
    sleep 1
    echo "Launching ADIOS trace export from SOS..."
    LD_PRELOAD=/home/khuck/install/chaos-stable/lib/libatl.so:/home/khuck/install/chaos-stable/lib/libevpath.so python $HOME/src/sos_flow_experiments/sos_scripts/tau_profile_adios.py >& sosa.out &
    sleep 2
}

dspace() {
    echo "Launching Dataspaces..."
    ./dataspaces_server -s 1 -c 8 &

    while [ ! -f conf ]; do
        sleep 1s
    done

    while read line; do
        if [[ "$line" == *"="* ]]; then
            export ${line}
        fi
    done < conf
}

workflow() {
    # to use periodic, enable this variable
    #export TAU_SOS_PERIODIC=1
    #export TAU_SOS_PERIOD=1000000
    export TAU_PLUGINS=libTAU-sos-plugin.so
    export TAU_PLUGINS_PATH=/home/khuck/src/tau2/x86_64/lib/shared-papi-mpi-pthread-pdt-sos-adios

    echo "Launching heat_transfer_adios..."
    export PROFILEDIR=writer_profiles
    mpirun -np 6 ./heat_transfer_adios2 heat  3 2 120 50  50 500 & # >& ht.out &
    sleep 1

    echo "Launching stage_write..."
    export PROFILEDIR=reader_profiles
    mkdir reader_profiles
    export TAU_PROFILE_FORMAT=merged
    export TAU_VERBOSE=1
    mpirun -np 2 ./stage_write heat.bp staged.bp FLEXPATH "" MPI "" >& sw.out
    echo "done, exiting..."
    sleep 1
}

sos_launch
#dspace
workflow
grep "Bye after processing" sw.out
sleep 10
./sosd_stop
