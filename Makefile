# New Makefile attempt for super-dope optimized sickness

F90       = ifort
MPF90     = mpiifort
F90FLAGS  = -g -c

LOCAL=/mn/stornext/u3/hke/owl/local

#LAPACK
MKLPATH         = $(MKLROOT)
LAPACK_INCLUDE  =
LAPACK_LINK     = -shared-intel -Wl,-rpath,$(MKLPATH) -L$(MKLPATH)  -lmkl_intel_lp64 -lmkl_intel_thread -lmkl_core -lpthread

#CFITSIO
CFITSIO_INCLUDE =
CFITSIO_LINK    = -L$(LOCAL)/lib -lcfitsio

# HEALPIX
HEALPIX         = /mn/stornext/u3/hke/owl/local/src/dagsshealpix
HEALPIX_INCLUDE = -I$(HEALPIX)/include
HEALPIX_LINK    = -L$(HEALPIX)/lib -lhealpix

#Combine them
F90COMP         = $(F90FLAGS) $(LAPACK_INCLUDE) $(CFITSIO_INCLUDE) $(HEALPIX_INCLUDE)
LINK            = $(HEALPIX_LINK) $(CFITSIO_LINK) $(LAPACK_LINK)
OBJS            = utility_mod.o hashtbl.o param_mod.o linalg_mod.o data_mod.o dang.o
OUTPUT          = dang

# Executable
dang: $(OBJS)
	$(MPF90) $(OBJS) -qopenmp -parallel -o $(OUTPUT) $(LINK)

# Dependencies
linalg_mod.o           : utility_mod.o
data_mod.o             : utility_mod.o
param_mod.o            : utility_mod.o hashtbl.o
dang.o : utility_mod.o param_mod.o linalg_mod.o data_mod.o 

# Compilation stage
%.o : %.f90
	$(MPF90) -fpp $(F90COMP) -qopenmp -parallel -c $<

# Cleaning command
.PHONY: clean
clean:
	rm *.o *.mod *~ dang
