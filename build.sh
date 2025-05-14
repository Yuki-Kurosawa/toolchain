#!/bin/bash

# EXPORT SOME GLOBAL VARIABLES
export FIRST_STAGE_PREFIX="opt/toolchain-stage1"
export FINAL_PREFIX="opt/toolchain"
export PACKAGE_FORMAT="TAR"
export SKIP_SOURCE=1
export LIBC="gnu"
export TARGET="x86_64-ksyuki-linux-$LIBC"
export SRCROOT=$(pwd)/sources
export BUILDROOT=$(pwd)/buildroot

# DEFINE SOME VARIABLES FOR BUILD ENV
set +h
umask 022
LFS=/
LC_ALL=POSIX
LFS_TGT=$TARGET
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=${LFS}${FINAL_PREFIX}/bin:${LFS}${FIRST_STAGE_PREFIX}/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE



DO_SOME_CHECKS()
{
	if [ "x$PACKAGE_FORMAT" = "x" ]; then
		echo "PACKAGE_FORMAT UNDEFINED, PLEASE DEFINE IT FIRST"
		return 1
	elif [ "x$PACKAGE_FORMAT" = "xTAR" ]; then
		echo "TAR WILL BE USED"
		tar --help > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo "TAR NOT FOUND, PLEASE CONFIGURE IT FIRST OR CHANGE PACKAGE_FORMAT"
			return 1
		fi
	elif [ "x$PACKAGE_FORMAT" = "xDEB" ]; then
		echo "DEB WILL BE USED"
		dpkg-buildpackage --help > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo "DEB BUILDER NOT FOUND, PLEASE CONFIGURE IT FIRST OR CHANGE PACKAGE_FORMAT"
			return 1
		fi
	elif [ "x$PACKAGE_FORMAT" = "xRPM" ]; then
		echo "RPM WILL BE USED"
		rpmbuild --help > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo "RPM BUILDER NOT FOUND, PLEASE CONFIGURE IT FIRST OR CHANGE PACKAGE_FORMAT"
			return 1
		fi
	else
		echo "PACKAGE FORMAT ${PACKAGE_FORMAT} NOT SUPPORTED, AVAILABLE FORMATS: TAR, DEB, RPM"
		return 1
	fi

	if [ "x$LIBC" = "xgnu" ]; then
		echo "GNU LIBC WILL BE USED"
	elif [ "x$LIBC" = "xmusl" ]; then
		echo "MUSL LIBC WILL BE USED"
	else
		echo "LIBC ${LIBC} NOT SUPPORTED, AVAILABLE LIBCS: gnu, musl"
		return 1
	fi

}

DOWNLOAD_SOURCES()
{
	if [ ! -d "sources" ]; then
		mkdir sources
	fi

	cd sources

	# download the sources
	if [ $SKIP_SOURCE -eq 1 ]; then
		echo "SOURCES DOWNLOAD SKIPPED"
		return 0
	fi

	rm -rf *.tar.*

	# first stage sources
	wget https://ftp.gnu.org/gnu/binutils/binutils-2.44.tar.xz
	wget https://ftp.gnu.org/gnu/gcc/gcc-15.1.0/gcc-15.1.0.tar.xz
	wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.14.6.tar.xz

	# libc sources
	if [ "x$LIBC" = "xgnu" ]; then
		wget https://ftp.gnu.org/gnu/glibc/glibc-2.41.tar.xz
	elif [ "x$LIBC" = "xmusl" ]; then
		wget https://musl.libc.org/releases/musl-1.2.5.tar.gz
	fi

	# gcc dependencies
	wget https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz
	wget https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.2.tar.xz
	wget https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz
	wget https://gcc.gnu.org/pub/gcc/infrastructure/isl-0.24.tar.bz2
	wget https://ftp.gnu.org/gnu/gettext/gettext-0.25.tar.xz


}

DO_FIRST_STAGE()
{
	cd $BUILDROOT
	tar xvf $SRCROOT/binutils-2.44.tar.xz
	cd binutils-2.44
	mkdir build
	cd build
	../configure --prefix=$LFS/$FIRST_STAGE_PREFIX \
             --with-sysroot=$LFS \
             --target=$LFS_TGT   \
             --disable-nls       \
             --enable-gprofng=no \
             --disable-werror    \
             --enable-new-dtags  \
             --enable-default-hash-style=gnu
	
	date > /tmp/build.log
	make
	make install
	date >> /tmp/build.log
	cd $BUILDROOT
}


MAIN(){
	DO_SOME_CHECKS
	DOWNLOAD_SOURCES
	echo $?
	DO_FIRST_STAGE
}

MAIN