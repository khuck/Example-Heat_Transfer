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
    ln -s ${HOME}/install/dataspaces/1.6.2/bin/dataspaces_server dataspaces_server 
fi
if [ ! -f heat_transfer_adios2 ] ; then
    ln -s ../heat_transfer_adios2 heat_transfer_adios2 
fi
if [ ! -f heat_transfer.xml ] ; then
     ln -s ../heat_transfer.xml heat_transfer.xml
fi
if [ ! -f stage_write ] ; then
    ln -s  ../stage_write/stage_write stage_write 
fi

if [ ! -f sosd ] ; then
    thepath=${HOME}/install/sos_flow/bin/sosd
    if [ ! -f ${thepath} ] ; then
        echo "Error! ${thepath} not found. Exiting."
        kill -INT $$
    fi
    ln -s ${thepath} sosd 
fi
if [ ! -f sosd_stop ] ; then
    thepath=${HOME}/install/sos_flow/bin/sosd_stop
    if [ ! -f ${thepath} ] ; then
        echo "Error! ${thepath} not found. Exiting."
        kill -INT $$
    fi
    ln -s ${thepath} sosd_stop 
fi

export SOS_CMD_PORT=22500
export SOS_WORK=`pwd`
export SOS_EVPATH_MEETUP=`pwd`

sos_launch() {
    sospath=${HOME}/install/sos_flow
    export PATH=$PATH:$sospath/bin
    export PYTHONPATH=$sospath/bin:$sospath/lib:$PYTHONPATH:`pwd`
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:`pwd`:$sospath/lib:${HOME}/install/chaos-stable/lib

    echo "Launching SOS..."
    ./sosd -l 0 -a 1 -k 0 -r aggregator -w ${SOS_WORK} >& sosd.out &
    sleep 1
    echo "Launching ADIOS trace export from SOS..."
    python ./simple.py >& sosa.out &
    sleep 2
}

workflow() {
    # to use periodic output (instead of iteration boundaries), enable this variable
    #export TAU_SOS_PERIODIC=1
    #export TAU_SOS_PERIOD=1000000
    export TAU_PLUGINS=libTAU-sos-plugin.so
    export TAU_PLUGINS_PATH=${HOME}/src/tau2/x86_64/lib/shared-papi-mpi-pthread-pdt-sos-adios

    echo "Launching heat_transfer_adios..."
    export PROFILEDIR=writer_profiles
    mpirun -np 6 ./heat_transfer_adios2 heat  3 2 120 50  10 500 & # >& ht.out &
    sleep 1

    echo "Launching stage_write..."
    export PROFILEDIR=reader_profiles
    mkdir reader_profiles
    mpirun -np 2 ./stage_write heat.bp staged.bp FLEXPATH "" MPI "" >& sw.out
    echo "done, exiting..."
    sleep 1
}

sos_launch
workflow
grep "Bye after processing" sw.out
sleep 2
./sosd_stop
