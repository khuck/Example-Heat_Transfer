CC=mpicc
FC=mpif90
ADIOS_CLIB=$(shell adios_config -l)
LINKER=$(CC)

ifeq ($(TAU),1)
	CC=tau_cc.sh -optTauSelectFile=select.tau
	ADIOS_CLIB=$(shell tau_cc.sh -tau:showlibs) $(shell adios_config -l)
	LINKER=$(CC)
endif

CFLAGS=-g -Og
FFLAGS=-g -Og -Wall #-fcheck=bounds #-fcheck=array-temps
LDFLAGS=-g -Og

## ADIOS_DIR/bin should in PATH env
ADIOS_INC=$(shell adios_config -c)

default: clean stage_write
all: default

OBJS = utils.o decompose_block.o 

%.o: %.c
	${CC} ${CFLAGS} -c ${ADIOS_INC} $<

stage_write: ${OBJS} stage_write.o

	${LINKER} ${LDFLAGS} -o stage_write ${OBJS} stage_write.o ${ADIOS_CLIB}
	@echo "Done"

test_decompose: ${OBJS} test_decompose.o 
	${LINKER} ${LDFLAGS} -o test_decompose ${OBJS} test_decompose.o ${ADIOS_CLIB}

clean:
	rm -f *.o *.mod *.fh core.*
	rm -f stage_write


distclean: clean
	rm -f log.* dataspaces.conf conf srv.lck *.bp

