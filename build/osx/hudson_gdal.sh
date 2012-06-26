#!/bin/bash

# Script directory
d=`dirname $0`

# Load versions
source ${d}/hudson_config.sh

function usage() {
  echo "Usage: $0 <destdir>"
  exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

srcdir=$PWD/files/gdal

if [ "x$1" = "x" ]; then
  destdir=$webroot
else
  destdir=$1
fi

# Get the GDAL source
get_file $gdal_url

# Clean up anything from a previous build and extract the sources into place
pushd files
rm -rf gdal
tar zxvf gdal-${gdal_version}.tar.gz
mv gdal-${gdal_version} gdal
popd

if [ ! -d $srcdir ]; then
  echo "Source directory is missing."
  exit 1
else 
  pushd $srcdir
fi

export CXXFLAGS="-O2 -arch i386 -arch x86_64 -mmacosx-version-min=10.5"
export CFLAGS="-O2 -arch i386 -arch x86_64 -mmacosx-version-min=10.5"
export ARCHFLAGS="-arch x86_64 -arch i386"
export LDFLAGS=${ARCHFLAGS}
./configure --prefix=${buildroot}/gdal --with-curl=/usr/bin/curl-config
make clean && make all
# Make sure the Java SWIG wrapper can find our java headers
sed -i -e 's:^JAVA_HOME.*:JAVA_HOME=/Library/Java/Home:' swig/java/java.opt

# Build MrSID plugin
g++ -g frmts/mrsid/*.cpp -dynamiclib -o gdal_MrSID.dylib \
-O2 -arch x86_64 -arch i386 -mmacosx-version-min=10.4 \
-DOGR_ENABLED -D_REENTRANT -DMRSID_J2K -fPIC -DPIC \
-Ifrmts/gtiff/libgeotiff/ -Igcore -Iogr -Iport -I${buildroot}/Raster_DSDK/include \
-L${buildroot}/Raster_DSDK/lib -L.libs \
-lgdal -lltidsdk -lpthread -ldl
# Build Java SWIG bindings
(cd swig/java; make)
checkrv $? "GDAL build"

rm -rf ${buildroot}/gdal
mkdir ${buildroot}/gdal
# Set BUILDROOT to install into hudson build dir
make install
# Install MrSID plugin
mkdir -p ${buildroot}/gdal/lib/gdalplugins
cp gdal_MrSID.dylib ${buildroot}/gdal/lib/gdalplugins
cp ${buildroot}/Raster_DSDK/lib/*.dylib ${buildroot}/gdal/lib
# Install Java SWIG bindings
cp swig/java/.libs/*.dylib ${buildroot}/gdal/lib
pushd ${buildroot}/gdal/
rm -f ${destdir}/gdal-osx.zip
zip -r9 ${destdir}/gdal-osx.zip *
checkrv $? "GDAL zip"
popd

popd

exit 0
    
