#!/bin/bash

set -e

UPYTH_VER="1.15"
UPYTH="micropython-${UPYTH_VER}"
UPYTH_CC_BASE=$(echo ${CC} | rev | cut -c4- | rev )

PREFIX_UPYTH="${TOPDIR}/phoenix-rtos-ports/micropython"
PREFIX_UPYTH_BUILD="${PREFIX_BUILD}/micropython"
PREFIX_UPYTH_PATCHSET="${PREFIX_UPYTH}/${UPYTH}-patchset"


b_log "Building micropython"
pushd .
cd $PREFIX_UPYTH


#
# Download
#
[ -f "${UPYTH}.tar.xz" ] || wget https://github.com/micropython/micropython/releases/download/v${UPYTH_VER}/${UPYTH}.tar.xz
[ -d "${UPYTH}" ] || ( echo "Unpacking ${UPYTH}.tar.xz..." && tar xf "${UPYTH}.tar.xz" )


#
# Patch
#
if ! patch -R -p0 -s -f --dry-run < ${PREFIX_UPYTH_PATCHSET}/lib.patch >/dev/null 2>&1
then
	patch -s -p0 < ${PREFIX_UPYTH_PATCHSET}/lib.patch
	patch -s -p0 < ${PREFIX_UPYTH_PATCHSET}/py.patch
	patch -s -p0 < ${PREFIX_UPYTH_PATCHSET}/mpy-cross.patch
	patch -s -p0 < ${PREFIX_UPYTH_PATCHSET}/os.patch
fi


#
# Setup flags for current architecture
#
if [[ ${UPYTH_CC_BASE} == "arm-phoenix-" ]]
then
	UPYTH_STACKSZ="4*512"
	UPYTH_HEAPSZ="16*1024"
	export LDFLAGS_EXTRA="-Wl,-q "
	export CFLAGS_EXTRA="-nostartfiles -fpic -fpie -msingle-pic-base -mno-pic-data-is-text-relative -DUPYTH_STACKSZ=${UPYTH_STACKSZ} -DUPYTH_HEAPSZ=${UPYTH_HEAPSZ}"
	export STRIPFLAGS_EXTRA="--strip-unneeded"
elif [[ ${UPYTH_CC_BASE} == "i386-pc-phoenix-" ]]
then
	UPYTH_STACKSZ="40000"
	UPYTH_HEAPSZ="1024*1024"
	export CFLAGS_EXTRA="-DUPYTH_STACKSZ=${UPYTH_STACKSZ} -DUPYTH_HEAPSZ=${UPYTH_HEAPSZ}"
	export STRIPFLAGS_EXTRA="--strip-unneeded"
else
	echo "Error: there is no micropython port for chosen architecture"
fi


#
# Build 
#
cd ${UPYTH}/mpy-cross && make clean && make all BUILD=${PREFIX_UPYTH_BUILD} CROSS_COMPILE=${UPYTH_CC_BASE} && cd ../..
cd ${UPYTH}/ports/unix && make clean && make all CROSS_COMPILE=${UPYTH_CC_BASE} PHOENIX_LD=${UPYTH_VER}
${UPYTH_CC_BASE}strip ${STRIPFLAGS_EXTRA} micropython


#
# Move binary
#
mkdir -p "${PREFIX_FS}/root/bin/" && cp micropython "${PREFIX_FS}/root/bin/"
cp micropython ${PREFIX_PROG_STRIPPED}

popd
