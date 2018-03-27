# How to run the Heat Transfer example with TAU and SOSflow

The following instructions assume a generic x86_64 cluster.

## Dependencies

First, make sure you have all the dependencies installed:

* [EVPath](https://gtkorvo.github.io)
* [ADIOS](https://github.com/ornladios/ADIOS) : using the EVPath installation for Flexpath support
* [SQLite3](https://www.sqlite.org)
* [SOS](http://github.com/cdwdirect/sos_flow) : using the EVPath installation, see build instructions below
* [PDT](http://tau.uoregon.edu) : requirement for TAU instrumentation support
* [TAU](http://tau.uoregon.edu) : using the ADIOS and SOS installations, see build instructions below

## Building Dependencies

The following instructions assume all software will be installed in ```$HOME/install```.

### EVPath

EVPath is typically installed with a few steps.  For more information, see [https://gtkorvo.github.io](https://gtkorvo.github.io).

```bash
# Get the build Perl script
wget https://gtkorvo.github.io/korvo_bootstrap.pl
# Run the script, specifying the version and installation location
perl ./korvo_bootstrap.pl stable $HOME/install/korvo-stable
# Build!
perl ./korvo_build.pl
```

### SOS

SOS has two required dependencies, SQLite3 and EVPath.  If SQLite3 is installed in the system path (including development files, i.e. headers), then the ```-DSQLite3_DIR``` argument is not required.  In order to build the Python support, the cffi module needs to be installed.  That can be installed with the command ```python -m pip install --user cffi``` (or installed in the default system location if you have root/sudo permission).

```bash
# Clone the repository
git clone https://github.com/cdwdirect/sos_flow.git
cd sos_flow

# Use CMake for configuration
mkdir build && cd build
cmake \
-DCMAKE_BUILD_TYPE=RelWithDebInfo \
-DCMAKE_INSTALL_PREFIX=$HOME/install/sos_flow \
-DSQLite3_DIR=$HOME/install/sqlite3 \
-DEVPath_DIR=$HOME/install/korvo-stable \
-DCMAKE_C_COMPILER=gcc \
-DCMAKE_CXX_COMPILER=g++ \
-DSOS_ENABLE_PYTHON=TRUE \
-DSOS_CLOUD_SYNC_WITH_EVPATH=TRUE \
..

# Compile and install
make -j
make install
```

### ADIOS

ADIOS can be a somewhat complicated configuration and build.  For more information, see [https://github.com/ornladios/ADIOS](https://github.com/ornladios/ADIOS).  Building the Python interface requires the mpi4py and numpy python modules.  The following instructions worked on an Ubuntu 16 Linux system:

```
# Get the source code:
git clone https://github.com/ornladios/ADIOS.git
cd ADIOS

# Build the autoconf environment
./autogen.sh

# Set some environment variables for the configure
export CC=gcc
export CXX=g++
export FC=gfortran
export MPICC=mpicc
export MPICXX=mpicxx
export MPIFC=mpif90
export CFLAGS="-fPIC -g -O2"
export CXXFLAGS="-fPIC -g -O2"
export FCFLAGS="-fPIC -g -O2"
export LDFLAGS="-fPIC -g -O2"

# Run the configure script - dataspaces and bzip2/zlib compression libraries are optional
./configure \
--prefix=$HOME/install/adios \
--enable-shared \
--disable-timers \
--disable-maintainer-mode \
--enable-dependency-tracking \
--with-flexpath=$HOME/install/korvo-stable \
--with-evpath=$HOME/install/korvo-stable \
--with-dataspaces=${dataspacesdir} \
--with-bzip2 \
--with-zlib

# Compile
make
make install

# Build the Python interface library
#Have 'adios_config' and 'python' in the path!

export PATH=$HOME/install/adios/bin:$PATH
cd wrappers/numpy

# Build without MPI
make clean
make python

# Install
python setup.py install --prefix=$HOME/install/adios

# MPI-enabled ADIOS wrapper can be built (MPI4Py is required):
make clean
make MPI=y python

# Install
python setup.py install --prefix=$HOME/install/adios

cd ../..
```

### PDT

PDT supports the instrumentation infrastruture for TAU.

```bash
wget http://tau.uoregon.edu/pdt.tgz
tar -xvzf pdt.tgz
cd pdtoolkit-3.25

./configure -GNU -prefix=$HOME/install/pdtoolkit-3.25
make
make install
```

### TAU

TAU is the final requirement.  PAPI is optional, and can be omitted from the configuration.  The configuration and build steps are:

```bash
# Get the latest master from private Git repo
wget http://tau.uoregon.edu/tau2.tgz
tar -xvzf tau2.tgz
cd tau2

# Configure and build
./configure \
-pdt=$HOME/install/pdtoolkit-3.25 \
-papi=/usr/local/papi/5.5.0 \
-sos=$HOME/install/sos_flow \
-mpi -pthread \
-adios=$HOME/install/adios

make install
```

## Building the Heat Transfer Example with TAU instrumentation

Now we can compile the Heat Transfer example with the TAU compiler, and link it all together.

First, set your environment to have ADIOS and TAU in your path, and set the TAU_MAKEFILE environment variable (If you omitted PAPI from your TAU configuration, don't include the '-papi' in the TAU Makefile name):

```bash
export PATH=$PATH:$HOME/install/adios/bin:$HOME/install/tau/x86_64/bin
export TAU_MAKEFILE=$HOME/install/tau/x86_64/lib/Makefile.tau-papi-mpi-pthread-pdt-sos-adios
```

Build with TAU:

```bash
cd $HOME/src/Example-Heat_Transfer
make TAU=1
cd stage_write
make TAU=1
cd ..
```

Edit the run script for your environment.  Please keep in mind that this example is configured for a single-node, 8 core workstation.  Cluster systems using PBS or Slurm will require submission scripts.  An example for that system is in ```test-sos-titan.sh```.

```bash
cd test_sos

# edit the file as necessary
vi test-sos.sh

# Run!
./test-sos.sh
```

