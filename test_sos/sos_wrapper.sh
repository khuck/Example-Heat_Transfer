#!/bin/bash

if [ "${myarch}" == "titan" ] ; then
	# set the environment
	module unload python
	module load python/2.7.9 python_mpi4py
fi

if [ -z ${SOS_WORK_DIR} ] ; then
    export SOS_WORK_DIR=`pwd`
fi

# First, clean up previous runs
rm -f ${SOS_WORK_DIR}/sosd.*

# next, launch the daemon

# The daemon is all the arguments. This is a wrapper script.
cmd=$*
echo ${cmd}
${cmd} &

# Wait for that to startup
while [ ! -f ${SOS_WORK_DIR}/sosd.00000.key ] ; do
    echo "Waiting for ${SOS_WORK_DIR}/sosd.00000.key..."
    sleep 1
done

# set paths.
if [ "${myarch}" == "titan" ] ; then
	# MPI for python
	export PYTHONPATH=/lustre/atlas2/csc143/world-shared/CODAR_demo/titan.gnu/python_mpi4py/lib/python2.7/site-packages:$PYTHONPATH
	# ADIOS for python
	export PYTHONPATH=/lustre/atlas/world-shared/csc143/khuck/CODAR/titan.gnu/install/adios/lib/python:$PYTHONPATH
	export PYTHONPATH=/lustre/atlas/world-shared/csc143/khuck/CODAR/titan.gnu/install/adios/lib/python2.7/site-packages:$PYTHONPATH
	# CFFI for python
	export PYTHONPATH=/lustre/atlas/world-shared/csc143/khuck/CODAR/titan.gnu/install/python:$PYTHONPATH
	export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/lustre/atlas/world-shared/csc143/khuck/CODAR/titan.gnu/install/evpath/lib
fi

# launch!
python ./tau_trace_adios.py >& sosa.out
