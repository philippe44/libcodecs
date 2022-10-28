#!/bin/bash

list="x86_64-linux-gnu-gcc x86-linux-gnu-gcc armhf-linux-gnueabi-gcc aarch64-linux-gnu-gcc \
      sparc64-linux-gnu-gcc mips-linux-gnu-gcc powerpc-linux-gnu-gcc x86_64-macos-darwin-gcc \
	  x86_64-freebsd-gnu-gcc x86_64-solaris-gnu-gcc"

declare -A alias=( [x86-linux-gnu-gcc]=i686-stretch-linux-gnu-gcc \
				   [x86_64-linux-gnu-gcc]=x86_64-stretch-linux-gnu-gcc \
				   [armhf-linux-gnueabi-gcc]=armv7-stretch-linux-gnueabi-gcc \
				   [aarch64-linux-gnu-gcc]=aarch64-stretch-linux-gnu-gcc \
				   [sparc64-linux-gnu-gcc]=sparc64-stretch-linux-gnu-gcc \
				   [mips-linux-gnu-gcc]=mips-stretch-linux-gnu-gcc \
				   [x86_64-macos-darwin-gcc]=x86_64-apple-darwin19-gcc \
				   [x86_64-freebsd-gnu-gcc]=x86_64-cross-freebsd12.3-gcc \
				   [x86_64-solaris-gnu-gcc]=x86_64-cross-solaris2.x-gcc )

declare -A cflags=( [sparc64-linux-gnu-gcc]="-mcpu=v7" \
                    [mips-linux-gnu-gcc]="-march=mips32" \
					[powerpc-linux-gnu-gcc]="-m32" )
					
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

library=libcodecs.a

# then iterate selected platforms/compilers
for cc in ${compilers[@]}
do
	IFS=- read -r platform host dummy <<< $cc

	export CPPFLAGS=${cppflags[$cc]}
	export CC=${alias[$cc]:-$cc} 
	export CXX=${CC/gcc/g++}
	export AR=${CC%-*}-ar
	export RANLIB=${CC%-*}-ranlib

	target=targets/$host/$platform	
	mkdir -p $target
	pwd=$(pwd)
	
	# build ogg
	item=ogg	
	if [ ! -f $target/lib$item.a ] || [[ -n $clean ]]; then
		cd $item
		./configure --enable-static --disable-shared --host=$platform-$host 
		make clean && make -j8
		cd $pwd
		
		cp $item/src/.libs/lib$item.a $target
		mkdir -p targets/include/$item
		cp -ur $item/include/* $_
		find $_ -type f -not -name "*.h" -exec rm {} +
	fi	

	# build vorbis
	item=vorbis
	if [ ! -f $target/lib$item.a ] || [[ -n $clean ]]; then
		cd $item
		./configure --enable-static --disable-shared --disable-oggtest --with-ogg-includes=$pwd/targets/include/ogg --with-ogg-libraries=$pwd/$target --host=$platform-$host 
		make clean && make -j8
		cd $pwd
		
		cp $item/lib/.libs/lib*.a $target
		mkdir -p targets/include/$item
		cp -ur $item/include/* $_
		find $_ -type f -not -name "*.h" -exec rm {} +
	fi	
	
	# build opus
	item=opus
	if [ ! -f $target/lib$item.a ] || [[ -n $clean ]]; then
		cd $item
		./configure --enable-static --disable-shared --disable-extra-programs --disable-doc --host=$platform-$host 
		make clean && make -j8
		cd $pwd
		
		cp $item/.libs/lib*.a $target
		mkdir -p targets/include/$item
		cp -ur $item/include/* $_
		find $_ -type f -not -name "*.h" -exec rm {} +
	fi	

	# build opusfile
	item=opusfile
	if [ ! -f $target/lib$item.a ] || [[ -n $clean ]]; then
		cd $item
		export DEPS_CFLAGS="-I../ogg/include -I../opus/include"
		export DEPS_LIBS=-s
		./configure --enable-static --disable-shared --disable-http --disable-examples --disable-doc --host=$platform-$host 
		make clean && make -j8
		unset DEPS_FLAGS
		unset DEPS_LIBS
		cd $pwd
		
		cp $item/.libs/lib*.a $target
		mkdir -p targets/include/$item
		cp -ur $item/include/* $_
		find $_ -type f -not -name "*.h" -exec rm {} +
	fi	

	# build faad2 (non-standard)
	item=faad2
	if [ ! -f $target/libfaad.a ] || [[ -n $clean ]]; then
		cd $item
		./configure --enable-static --disable-shared --host=$platform-$host 
		make clean && make -j8
		cd $pwd
		
		cp $item/libfaad/.libs/lib*.a $target
		mkdir -p targets/include/$item
		cp -ur $item/include/* $_
		find $_ -type f -not -name "*.h" -exec rm {} +
	fi	

	# build mad
	item=mad	
	if [ ! -f $target/lib$item.a ] || [[ -n $clean ]]; then
		cd $item
		./configure --enable-static --disable-shared --host=$platform-$host 
		make clean && make -j8
		cd $pwd
		
		cp $item/.libs/lib$item.a $target
		mkdir -p targets/include/$item
		cp -ur $item/mad.h $_
	fi		

	# build alac
	item=alac
	if [ ! -f $target/lib$item.a ] || [[ -n $clean ]]; then
		cd $item/codec
		make clean OBJDIR="../../build/$item" 
		make AR=$AR CC=${CC/gcc/g++} OBJDIR="../../build/$item" CFLAGS="-g -O3 -c $CPPFLAGS -Wno-multichar -Wno-register" -j8
		cd $pwd
	
		cp build/$item/lib$item.a $target
		mkdir -p targets/include/$item
		cp -u $item/codec/ALAC*.h $_
	fi
	
	# build flac (use "autogen.sh --no-symlink")
	item=flac	
	if [ ! -f $target/libFLAC-static.a ] || [[ -n $clean ]]; then
		cd $item
		./configure --enable-debug=no --enable-static --disable-shared --with-ogg-includes=$pwd/targets/include/ogg --with-ogg-libraries=$pwd/$target --disable-cpplibs --disable-oggtest --host=$platform-$host 
		make clean && make -j8
		cd $pwd
		
		cp $item/src/libFLAC/.libs/lib*-static.a $target
		cp $item/src/share/utf8/.libs/lib*.a $_
		mkdir -p targets/include/$item
		cp -ur $item/include/FLAC $_
		cp -ur $item/include/FLAC++ $_
		cp -ur $item/include/share $_
		find $_ -type f -not -name "*.h" -exec rm {} +
	fi	
	
	# build soxr
	item=soxr
	if [ ! -f $target/lib$item.a ] || [[ -n $clean ]]; then
		cd $item
		rm -rf build; mkdir -p build; cd build
		cmake .. -Wno-dev -DCMAKE_BUILD_TYPE="release" -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DWITH_OPENMP=OFF
		make clean && make -j8
		cd $pwd
		
		cp $item/build/src/lib$item.a $target
		mkdir -p targets/include/$item
		cp -ur $item/src/soxr.h $_
	fi	
		
	# build shine
	item=shine
	if [ ! -f $target/lib$item.a ] || [[ -n $clean ]]; then
		cd $item
		./configure --host=$platform-$host
		make clean && make -j8
		cd $pwd
		
		cp $item/.libs/lib$item.a $target
		mkdir -p targets/include/$item
		cp -u $item/src/lib/layer3.h $_
	fi
	
	# then build addons (all others *must* be built first)
	item=addons
	if [ ! -f $target/lib$item.a ] || [[ -n $clean ]]; then
		cd $item
		make clean && make PLATFORM=$platform HOST=$host -j8
		cd $pwd
		
		cp $item/build/lib$item.a $target
		mkdir -p targets/include/$item
		cp -u $item/alac_wrapper.h $_
	fi
	
	# finally concatenate all in a thin (if possible)
	rm -f $target/$library
	if [[ $host =~ macos ]]; then
		# libtool will whine about duplicated symbols
		${CC%-*}-libtool -static -o $target/$library $target/*.a 	
	else
		ar -rc --thin $target/$library $target/*.a
	fi	
done
