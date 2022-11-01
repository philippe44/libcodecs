#!/bin/bash

list="x86_64-linux-gnu-gcc x86-linux-gnu-gcc arm-linux-gnueabi-gcc aarch64-linux-gnu-gcc \
      sparc64-linux-gnu-gcc mips-linux-gnu-gcc powerpc-linux-gnu-gcc x86_64-macos-darwin-gcc \
	  arm64e-macos-darwin-cc x86_64-freebsd-gnu-gcc x86_64-solaris-gnu-gcc"

declare -A alias=( [x86-linux-gnu-gcc]=i686-stretch-linux-gnu-gcc \
                   [x86_64-linux-gnu-gcc]=x86_64-stretch-linux-gnu-gcc \
                   [arm-linux-gnueabi-gcc]=armv7-stretch-linux-gnueabi-gcc \
                   [aarch64-linux-gnu-gcc]=aarch64-stretch-linux-gnu-gcc \
                   [sparc64-linux-gnu-gcc]=sparc64-stretch-linux-gnu-gcc \
                   [mips-linux-gnu-gcc]=mips64-stretch-linux-gnu-gcc \
                   [powerpc-linux-gnu-gcc]=powerpc64-stretch-linux-gnu-gcc \
                   [x86_64-macos-darwin-gcc]=x86_64-apple-darwin19-gcc \
                   [arm64e-macos-darwin-cc]=arm64e-apple-darwin20.4-cc \
                   [x86_64-freebsd-gnu-gcc]=x86_64-cross-freebsd12.3-gcc \
                   [x86_64-solaris-gnu-gcc]=x86_64-cross-solaris2.x-gcc )

# There is a bug in this arm compiler for flac when O3 is selected so for now 
# everybody stays with O2. 
# TODO : add entries like [arm-linux-gnueabi-gcc#flac] to make fixes item-specific
declare -A cflags=( [sparc64-linux-gnu-gcc]="-mcpu=v7" \
                    [mips-linux-gnu-gcc]="-march=mips32" \
                    [powerpc-linux-gnu-gcc]="-m32" \
                    [arm-linux-gnueabi-gcc]="-O2" \
                    [x86_64-solaris-gnu-gcc]=-mno-direct-extern-access )
					
declare -a compilers

IFS= read -ra candidates <<< "$list"

# do we have "clean" somewhere in parameters (assuming no compiler has "clean" in it...
if [[ $@[*]} =~ clean ]]; then
	clean="clean"
fi	

# first select platforms/compilers
for cc in ${candidates[@]}; do
	# check compiler first
	if ! command -v ${alias[$cc]:-$cc} &> /dev/null; then
		if command -v $cc &> /dev/null; then
			unset alias[$cc]
		else	
			continue
		fi	
	fi

	if [[ $# == 0 || ($# == 1 && -n $clean) ]]; then
		compilers+=($cc)
		continue
	fi

	for arg in $@
	do
		if [[ $cc =~ $arg ]]; then 
			compilers+=($cc)
		fi
	done
done

# bootstrap environment if needed
for item in ogg flac alac shine mad vorbis opus opusfile faad2
do
	if [[ ! -f $item/configure && -f $item/configure.ac ]]; then
		echo "rebuilding ./configure for $item (if this fails, check ./autogen.sh and symlink usage)"
		cd $item
		if [[ -f autogen.sh ]]; then
			./autogen.sh --no-symlinks
		else 	
			autoreconf -if
		fi	
		cd ..
	fi
done

declare -A config=( [arm64e-macos]=aarch64-macos )

library=libcodecs.a

# then iterate selected platforms/compilers
for cc in ${compilers[@]}
do
	IFS=- read -r platform host dummy <<< $cc

	export CFLAGS=${cflags[$cc]}
	export CC=${alias[$cc]:-$cc} 
	export AR=${CC%-*}-ar
	export RANLIB=${CC%-*}-ranlib

	if [[ $CC =~ -gcc ]]; then
		export CXX=${CC%-*}-g++
	else 
		export CXX=${CC%-*}-c++
		CFLAGS+=" -fno-temp-file -stdlib=libc++"
	fi	

	CONFIG=${config["$platform-$host"]:-"$platform-$host"}
	
	target=targets/$host/$platform	
	mkdir -p $target
	pwd=$(pwd)
	
	# build alac
	item=alac
	if [ ! -f $target/lib$item.a ] || [[ -n $clean ]]; then
		cd $item/codec
		make clean OBJDIR="../../build/$item" 
		make AR=$AR CC=$CXX OBJDIR="../../build/$item" CFLAGS="-DTARGET_OS_MAC=0 -g -O3 -c -x c++ -Wno-multichar -Wno-register $CFLAGS" 
		cd $pwd
	
		cp build/$item/lib$item.a $target
		mkdir -p targets/include/$item
		cp -u $item/codec/ALAC*.h $_
	fi
done
