# How to run this example on Cori.nersc.gov:

## Environmenet setup

Source the CODAR build environment shell script:

```bash
source /global/project/projectdirs/m3084/cluster2018/source-me-tau.sh
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

Make sure that both heat_transfer.xml and run_cori.slurm specify the same
ADIOS transfer method (either DATASPACES or FLEXPATH).

```
cd test_sos
cp ../heat_transfer.xml .
cp ../dataspaces.conf .
sbatch run_cori.slurm
```

## To add ADIOS profile/trace extraction:

In the test_sos directory, clone the SOS scripts repo:

```
cd test_sos
git submodule foreach --recursive git checkout master
```

Then run the example set up for profile extraction or trace extraction (making
sure that the same ADIOS transfer method is set, similar to previous example):

```bash
# For profile collection:
sbatch run_cori_profile.slurm
# For trace collection:
sbatch run_cori_trace.slurm
```
