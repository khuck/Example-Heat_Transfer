#!/bin/bash

# cleanup, just in case
rm -rf staged.bp* conf ht.out sw.out sosd.* tau-metrics.* *_profiles
killall -9 mpirun dataspaces_server sosd

set -e

# Make sure that SOS, Dataspaces (if using) are in your path, or
# specify them here:

DATASPACES_CMD=`which dataspaces_server`
STAGE_WRITE_CMD=../stage_write/stage_write
SOSD_CMD=`which sosd` 
SOSD_STOP_CMD=`which sosd_stop` 
HEAT_TRANSFER_CMD=../heat_transfer_adios2

# Link some necessary configuration files
if [ ! -f dataspaces.conf ] ; then
    ln -s ../dataspaces.conf dataspaces.conf
fi

if [ ! -f heat_transfer.xml ] ; then
     ln -s ../heat_transfer.xml heat_transfer.xml
fi

# Set Common SOS environment variables

export SOS_CMD_PORT=22500 # The port where sosd listeners will allow connections
export SOS_WORK=`pwd` # Where sosd databases will be written
export SOS_EVPATH_MEETUP=`pwd` # Where sosd aggregator key files will be found for discovery
export SOS_BATCH_ENVIRONMENT=1 # disable "pretty print" output from sosd servers
export SOS_IN_MEMORY_DATABASE=1 # Use an in-memory database for sosd services (not $SOS_WORK)
export SOS_EXPORT_DB_AT_EXIT=verbose # At end of execution, write in-memory database to $SOS_WORK

sos_launch() {
    # Launch the SOS aggregator daemon.  We are running everything on one node,
    # So we don't need any listeners (the aggregator will also serve as the listener)
    echo "Launching SOS..."
    ${SOSD_CMD} -l 0 -a 1 -k 0 -r aggregator -w ${SOS_WORK} >& sosd.out &
    sleep 1

    # Launch the python code that will export the TAU data as an ADIOS BP file.
    # Make sure the PYTHONPATH is set to find all the ADIOS, SOS and related python modules.
    adiospath=${HOME}/src/ADIOS/ADIOS-gcc/lib/python
    adiospath2=${HOME}/src/ADIOS/ADIOS-gcc/lib/python2.7/site-packages
    sospath=${HOME}/install/sos_flow
    export PATH=$PATH:$sospath/bin
    export PYTHONPATH=$sospath/bin:$sospath/lib:$PYTHONPATH:`pwd`:$adiospath2
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:`pwd`:$sospath/lib:$adiospath2:${HOME}/install/chaos-stable/lib

    echo "Launching ADIOS trace export from SOS..."
    python ${HOME}/src/sos_flow_experiments/sos_scripts/tau_trace_adios.py >& sosa.out &
    sleep 2
}

dspace() {
    echo "Launching Dataspaces..."
    ${DATASPACES_CMD} -s 1 -c 8 &

    # Wait for the Dataspaces conf file to appear
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
    # The programs are instrumented with TAU, and at the end of phases, TAU
    # will write data to SOS.  If not, we could have the data be written periodically.
    # To use periodic output (instead of iteration boundaries), enable these variables
    #export TAU_SOS_PERIODIC=1
    #export TAU_SOS_PERIOD=1000000

    # Tell TAU where to find the SOS plugin.  This was built with TAU, if TAU was
    # configured with -sos=/path/to/sos/installation
    export TAU_PLUGINS=libTAU-sos-plugin.so
    export TAU_PLUGINS_PATH=${HOME}/src/tau2/x86_64/lib/shared-papi-mpi-pthread-pdt-sos-adios
    # To reduce the amount of data sent from TAU to SOS, use a filter file:
    # export TAU_SOS_SELECTION_FILE=`pwd`/sos_filter.txt
    # Tell TAU to send a full event trace to SOS:
    export TAU_SOS_TRACING=1
    # The shutdown delay only matters when TAU spawns the listeners.
    # That isn't happening in this example.
    #export TAU_SOS_SHUTDOWN_DELAY_SECONDS=30
    # Tell TAU to collect send/recv data as a communication matrix
    export TAU_COMM_MATRIX=1

    # Launch the heat transfer program
    echo "Launching heat_transfer_adios..."
    # Tell TAU where to put its profiles from the heat transfer application
    export PROFILEDIR=writer_profiles
    mkdir -p writer_profiles
    mpirun -np 6 ${HEAT_TRANSFER_CMD} heat  3 2 120 50  10 500 &
    sleep 1

    # Launch the stage write program
    echo "Launching stage_write..."
    # Tell TAU where to put its profiles from the stage write application
    export PROFILEDIR=reader_profiles
    mkdir reader_profiles
    mpirun -np 2 ./stage_write heat.bp staged.bp FLEXPATH "" MPI "" >& sw.out
    echo "done, exiting..."
    sleep 1
}

sos_launch
#dspace
workflow
grep "Bye after processing" sw.out
# Wait for SOS to finish ADIOS output - this sleep is necessary because of the
# large number of MPI_Send() calls in the stage_write application, and the large
# volume of trace data, even for this small example.
sleep 30
./sosd_stop
