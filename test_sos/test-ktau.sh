#!/bin/bash

# cleanup
rm -rf staged.bp* conf ht.out sw.out sosd.* tau-metrics.*

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

echo "Launching Dataspaces..."
./dataspaces_server -s 1 -c 8 >& ds.out &

while [ ! -f conf ]; do
    sleep 1s
done

while read line; do
    if [[ "$line" == *"="* ]]; then
        export ${line}
    fi
done < conf

export SOS_CMD_PORT=22500
export SOS_WORK=`pwd`
export SOS_EVPATH_MEETUP=`pwd`

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
#LD_PRELOAD=/home/khuck/install/chaos-stable/lib/libatl.so:/home/khuck/install/chaos-stable/lib/libevpath.so python $HOME/src/sos_flow_experiments/sos_scripts/tau_trace_adios.py &
sleep 1

# to use periodic, enable this variable, and comment out the
# TAU_SOS_send_data() call in matmult.c.
export TAU_SOS_PERIODIC=1
#export TAU_SOS_PERIOD=1000000
export TAU_SOS_HIGH_RESOLUTION=1
export TAU_SOS=1
export TAU_PLUGINS=libTAU-sos-plugin.so
export TAU_PLUGINS_PATH=/home/khuck/src/tau2/x86_64/lib/shared-papi-mpi-pthread-pdt-sos-adios

echo "Launching heat_transfer_adios..."
export PROFILEDIR=writer_profiles
mpirun -np 6 ./heat_transfer_adios2 heat  3 2 120 50  10 500 >& ht.out &
sleep 1

echo "Launching stage_write..."
export PROFILEDIR=reader_profiles
mpirun -np 2 ./stage_write heat.bp staged.bp DATASPACES "" MPI "" >& sw.out 
echo "done, exiting..."
sleep 2

grep "Bye after processing" sw.out
./sosd_stop >& /dev/null
