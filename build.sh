#!/usr/bin/env bash

# Script for compiling FVCOM-FABM-ERSEM for benchmarking
#
# The build is split into three phases:
#
# 1) Build the FABM-ERSEM library. Here, ERSEM is a marine
# biogeochemical model while FABM is a piece of software
# which allows the ocean model (FVCOM) and ERSEM to
# communicate. ERSEM's main job is to compute d/dt sink/source
# terms for biogeochemical tracers. FABM communicates these
# to FVCOM, which in turn factors them in during the
# forward integration of the model.
#
# 2) Build FVCOM ancillary libraries. These include the
# sub-packages julian, metis, fproj and proj which are
# distributed with the FVCOM source code to facilitate
# the build process.
#
# 3) Build FVCOM.
#
#
# Notes
# -----
# 
# FVCOM itself uses a fairly old-school approach to building
# the FVCOM executable, which is based around make. The
# FABM-ERSEM library is built using cmake.
#
# In the example below, we use the GNU compiler suite on
# ARCHER2. If using a different compiler, one will need
# to specify this both when building the FABM-ERSEM library
# (see below) and when building FVCOM. The latter is achieved
# by editing the file "make.inc", which is found in the
# "build_utils" sub-directory, which can be found in the main
# FABM source code directory. We have provided a number of
# example make.inc files. Here we use one designed to work
# with ARCHER2.
#
# Other dependencies include cmake and the NetCDF libraries which
# are loaded using the module command.
#
# ---------------------------------------------------------------------

set -euo pipefail


# <<TO CHANGE - Load required modules (tested on ARCHER2)>>
module purge
module load load-epcc-module 
module load epcc-setup-env
module load PrgEnv-gnu
module load craype-x86-rome
# stick to GNU 10.3
# module load gcc/10.3.0
module load cmake
# for metis
module load metis
# for petsc (requires parallel HDF5)
module load cray-hdf5-parallel/1.12.2.7
module load cray-netcdf-hdf5parallel/4.9.0.7
module load petsc/3.18.5
# module load petsc/3.24.1

# Set INCLUDEPATH and LIBPATH for ARCHER2 Cray modules
# Note: These are not automatically set by all modules, so we construct them manually
# These are needed if not using the local LIB and INCLUDE paths in the make.inc file when building FVCOM. 
#If so, and not all libraries are covered by the module loads, then add the local libs and include paths here too (e.g. -I${CODE_DIR}/libs/install/include and -L${CODE_DIR}/libs/install/lib for fproj and proj and julian).  
# export INCLUDEPATH="/opt/cray/pe/mpich/8.1.27/ofi/gnu/9.1/include:/opt/cray/pe/hdf5-parallel/1.12.2.7/gnu/9.1/include:/opt/cray/pe/netcdf-hdf5parallel/4.9.0.7/gnu/9.1/include:${PETSC_DIR}/include:${PETSC_DIR}"

# export LIBPATH="/opt/cray/pe/mpich/8.1.27/ofi/gnu/9.1/lib:/opt/cray/pe/hdf5-parallel/1.12.2.7/gnu/9.1/lib:/opt/cray/pe/netcdf-hdf5parallel/4.9.0.7/gnu/9.1/lib:${PETSC_DIR}/lib"

# Root directory - assumes the package has been unzipped into an
# appropriate location on the HPC (e.g. somewhere in /work).
ROOT_DIR=$(pwd)

# All other paths are set relative to ROOTDIR
CODE_DIR="${ROOT_DIR}/src"
BUILD_DIR="${ROOT_DIR}/build"
INSTALL_DIR="${ROOT_DIR}/install"


# # Step 1 - Build the FABM-ERSEM library
# # -------------------------------------

# echo "STEP 1: Building the FABM-ERSEM library"

FABM_SRC_DIR="${CODE_DIR}/fabm/src"
ERSEM_SRC_DIR="${CODE_DIR}/ersem/src"
FABM_BUILD_DIR="${BUILD_DIR}/fabm"
FABM_INSTALL_DIR="${INSTALL_DIR}/fabm"

if [ ! -d ${FABM_BUILD_DIR} ]; then
    mkdir -p ${FABM_BUILD_DIR}
fi
if [ ! -d ${FABM_INSTALL_DIR} ]; then
    mkdir -p ${FABM_INSTALL_DIR}
fi

# FVCOM's Fortran module dependencies are not parallel-safe here.
# Force a serial build even if the shell environment exports MAKEFLAGS=-j...
NJOBS=1
unset MAKEFLAGS
unset MFLAGS

# cd $FABM_BUILD_DIR

# cmake ${FABM_SRC_DIR} -DCMAKE_INSTALL_PREFIX=${FABM_INSTALL_DIR} \
#       -DFABM_ERSEM_BASE=${ERSEM_SRC_DIR} -DFABM_HOST=fvcom \
#       -DCMAKE_Fortran_COMPILER=$(which ftn)
# make install -j ${NJOBS}

# cd ${ROOT_DIR}

# Step 2 - Build FVCOM ancillary libraries
# ----------------------------------------

echo "STEP 2: Building FVCOM ancillary libraries"

FVCOM_TOP_DIR="${CODE_DIR}/"
FVCOM_LIBS_DIR="${CODE_DIR}/libs"
# make allclean TOPDIR=${FVCOM_TOP_DIR} BIODIR=${FABM_INSTALL_DIR}
# # <<TO_CHANGE - make.inc for compiler flags etc (tested on ARCHER2)>>
ln -sf ${FVCOM_TOP_DIR}/build_utils/make_PML_ARCHER2.inc.default ${FVCOM_TOP_DIR}/make.inc

# cd ${FVCOM_LIBS_DIR}

# make TOPDIR=${FVCOM_TOP_DIR} BIODIR=${FABM_INSTALL_DIR}
# make clean TOPDIR=${FVCOM_TOP_DIR} BIODIR=${FABM_INSTALL_DIR}

cd ${ROOT_DIR}

# Step 3 - Build FVCOM
# ----------------------------------------

echo "STEP 3: Build FVCOM"

cd ${FVCOM_TOP_DIR}
# metis
# The magic flag FLAG_411 = -DMETIS_5 needs to be accompanied by
# "make FLAG_411=true" to ensure the file partition.c is included
# in the objects to link.
# As we are using the module-supplied metis, the include/lib
# options can be omitted

make -j${NJOBS} TOPDIR=${FVCOM_TOP_DIR} BIODIR=${FABM_INSTALL_DIR} libfvcom
make -j${NJOBS} FLAG_411=true TOPDIR=${FVCOM_TOP_DIR} BIODIR=${FABM_INSTALL_DIR}
# make clean TOPDIR=${FVCOM_TOP_DIR} BIODIR=${FABM_INSTALL_DIR}

cd ${ROOT_DIR}

# Check if we have an executable and finish
FVCOM_EXE="${FVCOM_TOP_DIR}/fvcom"
if [ -x ${FVCOM_EXE} ]; then
    FVCOM_RUN_DIR="${ROOT_DIR}/run"
    rsync -avP ${FVCOM_EXE} ${FVCOM_RUN_DIR}/bin/ && echo "Build was successful"
else
    echo "Build failed"
fi

