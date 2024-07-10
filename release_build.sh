#/bin/sh
export PREFIX=$THEOS/toolchain/Xcode.arm64eLegacy.xctoolchain/usr/bin/
make clean package FINALPACKAGE=1
echo "ROOTFUL BUILD DONE"

export -n PREFIX
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
echo "ROOTLESS BUILD DONE"