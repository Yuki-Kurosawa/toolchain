#!/bin/bash

# EXPORT SOME GLOBAL VARIABLES
export FIRST_STAGE_PREFIX="opt/toolchain-stage1"
export FINAL_PREFIX="opt/toolchain"
export PACKAGE_FORMAT="TAR"
export SKIP_SOURCE=1
export LIBC="gnu"
export TARGET="x86_64-ksyuki-linux-$LIBC"
export THISROOT=$(pwd)
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
	# build binutils pass 1	
	tar xvf $SRCROOT/binutils-2.44.tar.xz
	cd binutils-2.44
	mkdir build
	cd build
	../configure --prefix=$LFS$FIRST_STAGE_PREFIX \
             --with-sysroot=$LFS \
             --target=$LFS_TGT   \
             --disable-nls       \
             --enable-gprofng=no \
             --disable-werror    \
             --enable-new-dtags  \
             --enable-default-hash-style=gnu
		
	make
	make install

	cd $BUILDROOT
	rm -rvf *

	#build gcc pass 1
	tar xvf $SRCROOT/gcc-15.1.0.tar.xz
	cd gcc-15.1.0
	tar xvf $SRCROOT/gmp-6.3.0.tar.xz
	tar xvf $SRCROOT/mpfr-4.2.2.tar.xz
	tar xvf $SRCROOT/mpc-1.3.1.tar.gz
	tar xvf $SRCROOT/isl-0.24.tar.bz2

	mv gmp-6.3.0 gmp
	mv mpfr-4.2.2 mpfr
	mv mpc-1.3.1 mpc
	mv isl-0.24 isl

	case $(uname -m) in
	x86_64)
		sed -e '/m64=/s/lib64/lib/' \
			-i.orig gcc/config/i386/t-linux64
	;;
	aarch64)
		sed -e '/mabi.lp64=/s/lib64/lib/' \
			-i.orig gcc/config/aarch64/t-aarch64-linux
	;;
	esac

	mkdir -v build
	cd build

	if [ "x$LIBC" = "xgnu" ]; then
		../configure                  \
			--target=$LFS_TGT         \
			--prefix=$LFS$FIRST_STAGE_PREFIX       \
			--with-glibc-version=2.41 \
			--with-sysroot=$LFS       \
			--with-newlib             \
			--without-headers         \
			--enable-default-pie      \
			--enable-default-ssp      \
			--disable-nls             \
			--disable-shared          \
			--disable-multilib        \
			--disable-threads         \
			--disable-libatomic       \
			--disable-libgomp         \
			--disable-libquadmath     \
			--disable-libssp          \
			--disable-libvtv          \
			--disable-libstdcxx       \
			--enable-languages=c,c++
	elif [ "x$LIBC" = "xmusl" ]; then
		../configure                  \
			--target=$LFS_TGT         \
			--prefix=$LFS$FIRST_STAGE_PREFIX       \
			--with-sysroot=$LFS       \
			--with-newlib             \
			--without-headers         \
			--enable-default-pie      \
			--enable-default-ssp      \
			--disable-nls             \
			--disable-shared          \
			--disable-multilib        \
			--disable-threads         \
			--disable-libatomic       \
			--disable-libgomp         \
			--disable-libquadmath     \
			--disable-libssp          \
			--disable-libvtv          \
			--disable-libstdcxx       \
			--enable-languages=c,c++
	fi

	make
	make install

	cd $BUILDROOT
	rm -rvf *

	# install kernel headers
	tar xvf $SRCROOT/linux-6.14.6.tar.xz
	cd linux-6.14.6
	make mrproper
	make headers
	find usr/include -type f ! -name '*.h' -delete
	cp -rv usr/include $LFS/$FINAL_PREFIX/usr

	cd $BUILDROOT
	rm -rvf *

}

TEST_GCC_STAGE1()
{
	$TARGET-gcc -v
	$TARGET-gcc -o $THISROOT/elf $THISROOT/elf.c
	$THISROOT/elf
	rm -v $THISROOT/elf
}


MAIN(){
	DO_SOME_CHECKS
	DOWNLOAD_SOURCES
	DO_FIRST_STAGE
	TEST_GCC_STAGE1
}

MAIN