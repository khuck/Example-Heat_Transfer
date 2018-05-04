# How to run this example on titan.ccs.ornl.gov:

## Environmenet setup

Source the CODAR build environment shell script:

```bash
source /lustre/atlas/proj-shared/csc249/CSC249ADCD01/software2/sourceme-titan.sh
```

## Build the software:

Build the heat_transfer_adios2 and stage_write examples:

```
cd Example-Heat_Transfer
make TAU=1
cd stage_write
make TAU=1
cd ..
```

## Set up and run the example:

Make sure that both heat_transfer.xml and run_titan_small.pbs specify the same
ADIOS transfer method (either DATASPACES or FLEXPATH).

```
cd test_sos
cp ../heat_transfer.xml .
cp ../dataspaces.conf .
sbatch run_titan_small.pbs
```

## To add ADIOS profile/trace extraction:

In the test_sos directory, clone the SOS scripts repo:

```
cd test_sos
git submodule update --recursive --remote
git submodule update --init sos_flow_experiments
git submodule foreach git pull origin master
```

Then run the example set up for profile extraction or trace extraction (making
sure that the same ADIOS transfer method is set, similar to previous example):

```bash
# For profile collection:
sbatch run_titan_profile.pbs
# For trace collection:
sbatch run_titan_trace.pbs
```
