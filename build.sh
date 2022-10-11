#!/bin/bash

list="x86_64-linux-gnu-gcc x86-linux-gnu-gcc arm-linux-gnueabi-gcc aarch64-linux-gnu-gcc sparc64-linux-gnu-gcc mips-linux-gnu-gcc powerpc-linux-gnu-gcc"
declare -A alias=( [x86-linux-gnu-gcc]=i686-linux-gnu-gcc )
declare -A cppflags=( [mips-linux-gnu-gcc]="-march=mips32" [powerpc-linux-gnu-gcc]="-m32")
declare -a compilers

IFS= read -ra candidates <<< "$list"

# do we have "clean" somewhere in parameters (assuming no compiler has "clean" in it...
if [[ $@[*]} =~ clean ]]; then
	clean="clean"
fi	

# first select platforms/compilers
for cc in ${candidates[@]}
do
	# check compiler first
	if ! command -v ${alias[$cc]:-$cc} &> /dev/null; then
		continue
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
for item in ogg flac alac shine
do
	if [[ ! -f $item/configure && -f $item/configure.ac ]]; then
		cd $item
		if [[ -f autogen.sh ]]; then
			./autogen.sh --no-symlinks
		else 	
			autoreconf -if
		fi	
		cd ..
	fi
done

library=libcodecs.a

# then iterate selected platforms/compilers
for cc in ${compilers[@]}
do
	IFS=- read -r platform host dummy <<< $cc

	export CPPFLAGS=${cppflags[$cc]}
	export CC=${alias[$cc]:-$cc} 
	export CXX=${CC/gcc/g++}

	target=targets/$host/$platform	
	mkdir -p $target
	pwd=$(pwd)
	
	# build ogg
	item=ogg	
	if [ ! -f $target/lib$item.a ] || [[ -n $clean ]]; then
		cd $item
		./configure --enable-static --disable-shared --host=$platform-$host 
		make clean && make
		cd $pwd
		
		cp $item/src/.libs/lib$item.a $target
		mkdir -p targets/include/$item
		cp -ur $item/include/* $_
		find $_ -type f -not -name "*.h" -exec rm {} +
	fi	
		

	# build alac
	item=alac
	if [ ! -f $target/lib$item.a ] || [[ -n $clean ]]; then
		cd $item/codec
		CC=${alias[$cc]:-$cc}
		make clean OBJDIR="../../build/$item" 
		make CC=${CC/gcc/g++} OBJDIR="../../build/$item" CFLAGS="-g -O3 -c ${cppflags[$cc]} -Wno-multichar -Wno-register"
		cd $pwd
	
		cp build/$item/lib$item.a $target
		mkdir -p targets/include/$item
		cp -u $item/codec/ALAC*.h $_
	fi
	
	# build flac (use "autogen.sh --no-symlink")
	item=flac	
	if [ ! -f $target/libFLAC-static.a ] || [[ -n $clean ]]; then
		cd $item
		./configure  --enable-debug=no --enable-static --disable-shared --with-ogg-includes=$pwd/targets/include/ogg --with-ogg-libraries=$pwd/$target --disable-cpplibs --disable-oggtest --host=$platform-$host 
		make clean && make
		cd $pwd
		
		cp $item/src/libFLAC/.libs/lib*-static.a $target
		cp $item/src/share/utf8/.libs/lib*.a $_
		mkdir -p targets/include/$item
		cp -ur $item/include/FLAC $_
		cp -ur $item/include/FLAC++ $_
		cp -ur $item/include/share $_
		find $_ -type f -not -name "*.h" -exec rm {} +
	fi	
	
	# build shine
	item=shine
	if [ ! -f $target/lib$item.a ] || [[ -n $clean ]]; then
		cd $item
		./configure --host=$platform-$host
		make clean && make
		cd $pwd
		
		cp $item/.libs/lib$item.a $target
		mkdir -p targets/include/$item
		cp -u $item/src/lib/layer3.h $_
	fi
	
	# then build addons (all others *must* be built first)
	item=addons
	if [ ! -f $target/lib$item.a ] || [[ -n $clean ]]; then
		cd $item
		make clean && make CC=${CC/gcc/g++} PLATFORM=$platform
		cd $pwd
		
		cp $item/build/lib$item.a $target
		mkdir -p targets/include/$item
		cp -u $item/alac_wrapper.h $_
	fi
	
	# finally concatenate all in a thin
	rm -f $target/$library
	ar -rc --thin $target/$library $target/*.a
done
