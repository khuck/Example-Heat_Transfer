#!/bin/bash

#SBATCH -N 4
#SBATCH -A m3084
#SBATCH -p debug
#SBATCH -C haswell
#SBATCH -t 00:15:00
#SBATCH -o run_sos-%j.out
#SBATCH -A m3084
#SBATCH --mail-type=ALL
#SBATCH --mail-user=khuck@cs.uoregon.edu

###
#
# SLURM submission script for running on cori.nersc.gov
#
# This example uses 4 nodes:
# - one for dataspaces_server 
# - one for the sosd aggregator daemon
# - one for the heat_transfer application
# - one for the stage_write application
#
# Each time that srun is called, one node in the allocation is consumed.
# The TAU library in both the heat_transfer and stage_write applications will
# spawn an SOS listener daemon on each appliation node, and those will connect
# with the SOS aggregator daemon.  At the end of execution, TAU sends a shutdown
# message to the listener daemons, which is propagated to the aggregator daemon
# and all services should exit.
#
###

###
# -------------------- set the environment -------------------- #
###

# change to the directory where we were launched
cd $SLURM_SUBMIT_DIR

# get the current working directory
export cwd=`pwd`
echo ${cwd}

# Set up modules, set paths
source /global/project/projectdirs/m3084/cluster2018/khuck/sourceme-cori-gcc-debug.sh

# cleanup, just in case
rm -rf staged.bp* conf ht.out sw.out sosd.* tau-metrics.* *_profiles

###
# -------------------- Launch the dataspaces server  -------------- #
###

# launch the dataspaces server - Slurm will take the first node of the allocation

#echo "Launching Dataspaces..."
srun -n 1 -N 1 dataspaces_server -s 1 -c 20 &

while [ ! -f conf ]; do
    sleep 1s
done
echo "got config, continuing"

while read line; do
    if [[ "$line" == *"="* ]]; then
        export ${line}
    fi
done < conf
sleep 1

###
# -------------------- Launch the SOS aggregator -------------- #
###

###
# Set up SOS environment variables.  These will be used by both the aggregator
# and the listener daemons.
###

# the port that applications will connect to for the local listener daemon
export SOS_CMD_PORT=22500
# the directory where SOS will write output (if requested)
export SOS_WORK=${cwd}
# the directory where SOS will write .key files for network self-discovery
export SOS_EVPATH_MEETUP=${cwd}
# disable pretty-print of SOS output
export SOS_BATCH_ENVIRONMENT=1
# use SQLite3 in "in memory" mode - no disc
export SOS_IN_MEMORY_DATABASE=1
# After execution, write the database to disc with some verbose messages
export SOS_EXPORT_DB_AT_EXIT=VERBOSE
# The base command to launch SOS daemons - used by both aggregator and listeners
export sos_cmd="${SOS_ROOT}/bin/sosd -l 5 -a 1 -w ${SOS_WORK}"
# The listener daemon command, to be forked from 1 application rank per node
export SOS_FORK_COMMAND="${sos_cmd} -k @LISTENER_RANK@ -r listener"

# launch the aggregator - Slurm will take the second node of the allocation
# and the aggregator will be "rank" 0 in the SOS processes. Launch
# in the background, so we can continue launching other srun calls.
echo "Launching sosd aggregator"
ulimit -c unlimited
#srun -n 1 -N 1 -c 8 ${sos_cmd} -k 0 -r aggregator >& sosd.out &
touch sosd.00000.key

# Wait for the EVPath discovery information
while [ ! -f sosd.00000.key ]; do
    sleep 1s
done
echo "got config, continuing"

###
# --------- Set some common settings for the applications ----- #
###

# What is the name of the TAU SOS plugin?
#export TAU_PLUGINS=libTAU-sos-plugin.so
# Where can TAU find the SOS plugin?
export TAU_PLUGINS_PATH=/global/project/projectdirs/m3084/cluster2018/tau/tau/craycnl/lib/shared-gnu-papi-mpi-pthread-pdt-sos-adios
# Should we filter the data going to SOS from TAU?
#export TAU_SOS_SELECTION_FILE=${cwd}/sos_filter.txt
# What PAPI metrics are we collecting?
export TAU_METRICS=TIME
# Collect P2P send/recv information like bytes sent
export TAU_COMM_MATRIX=1
# This is for Pookie data collection only!
#export TAU_SOS_TRACE_ADIOS=1
# To enable full event tracing - warning, can be high volume of data!
#export TAU_SOS_TRACING=1
# When not using dynamic phases (i.e. instrumenting with TAU, see ../select.tau) 
# Ask TAU to periodically write its data to SOS
#export TAU_SOS_PERIODIC=1
# How frequently? in microseconds.
#export TAU_SOS_PERIOD=1000000

###
# --------- Launch the listener app in the pipeline ----------- #
###

# 1 node doing heat transfer
# Slurm will take the third node(s) of the allocation
# Tell SOS how many application ranks per node there are
export SOS_APP_RANKS_PER_NODE=16
# Tell SOS what "rank" it's listeners should start with - the
# aggregator was "rank" 0, so this node's listener will be 1
export SOS_LISTENER_RANK_OFFSET=1
# Where should TAU write the profile data?
export PROFILEDIR=writer_profiles
mkdir writer_profiles

echo "Launching heat_transfer_adios..."
srun -n 16 -N 1 ${cwd}/../heat_transfer_adios2 heat 4 4 256 256  10 500 & # >& ht.out &
sleep 5

# last 1 node doing stage_write
# Slurm will take the fourth node of the allocation
# Tell SOS how many application ranks per node there are
export SOS_APP_RANKS_PER_NODE=4
# Tell SOS what "rank" it's listeners should start with - the
# aggregator was "rank" 0, and the reader node was 1, 
# so this node's listener will start at 2
export SOS_LISTENER_RANK_OFFSET=2
# Where should TAU write the profile data?
export PROFILEDIR=reader_profiles
mkdir reader_profiles

echo "Launching stage_write..."
#srun -n 4 -N 1 /global/project/projectdirs/m3084/cluster2018/khuck/Example-Heat_Transfer/stage_write/stage_write heat.bp staged.bp DATASPACES "" POSIX "" >& sw.out
srun -n 4 -N 1 /global/project/projectdirs/m3084/cluster2018/khuck/Example-Heat_Transfer/stage_write/stage_write heat.bp staged.bp DATASPACES "" POSIX "" >& sw.out
echo "done, exiting..."
sleep 10

grep "Bye after processing" sw.out

# SOS should shut down all daemons on application exit, but just in case,
# you can kill them with this:
#killall -9 srun 

