#!/bin/bash

JNI_ARCHS=("armeabi" "armeabi-v7a" "x86")

set -e

self=$(readlink -f "$0")
base=$(dirname "${self}")

cd "${base}"

echo "Cleaning libs directory"
rm -rf tourenplaner-android-offline/libs/
mkdir -p tourenplaner-android-offline/libs/

ant() {
	local ANT=$(which ant 2>/dev/null)
	if [ ! -x "${ANT}" ]; then
		echo >&2 "ant: command not found"
		return 127
	fi
	"${ANT}" -Dant.build.javac.target=1.6 -Dant.build.javac.source=1.6 "$@"
}

(
	cd tourenplaner-android-offline/libs/
	echo "Symlinking downloaded .jar files"
	ln -s ../../downloads/*.jar ./
)

(
	cd mapsforge
	if [ -e mapsforge-map/target/mapsforge-map-*-jar-with-dependencies.jar ]; then
		echo "mapsforge already built, skipping"
	else
		echo "Building mapsforge"
		mvn package
	fi
)

(
	cd tourenplaner-android-offline/libs/
	echo "Symlinking mapsforge-map"
	ln -s ../../mapsforge/mapsforge-map/target/mapsforge-map-*-jar-with-dependencies.jar ./
)

# (
# 	cd xz-java
# 	if [ -e build/jar/xz.jar ]; then
# 		echo "xz-java already built, skipping"
# 	else
# 		echo "Building xz-java"
# 		ant
# 	fi
# )
# 
# (
# 	cd tourenplaner-android-offline/libs/
# 	echo "Symlinking xz-java"
# 	ln -s ../../xz-java/build/jar/xz.jar ./
# )

build_osmfind() {
	local ARMABI="$1"

	if [ ! -e "build_${ARMABI}/Makefile" ]; then
		echo "Invalid build dir found, removing it"
		rm -rf build_${ARMABI}
	fi

	if [ ! -d "build_${ARMABI}" ]; then
		echo "Preparing osmfind with cmake for architecture ${ARMABI}"
		mkdir "build_${ARMABI}"
		(
			cd "build_${ARMABI}"
			cmake \
				-DCMAKE_TOOLCHAIN_FILE=../cmake/android.toolchain.cmake \
				-DLIBRARY_OUTPUT_PATH_ROOT="../osmfind-android" \
				-DANDROID_ABI="${ARMABI}" \
				-DANDROID_NATIVE_API_LEVEL="android-9" \
				-DCMAKE_BUILD_TYPE="RelWithDebInfo" \
				../
		)
	fi

	(
		echo "Building osmfind for architecture ${ARMABI}"
		cd "build_${ARMABI}"
		make -j4
	)
}

(
	cd osmfind
	echo "Building osmfind"

	for arch in "${JNI_ARCHS[@]}"; do build_osmfind "${arch}"; done
)

(
	echo "Installing stripped osmfind libraries"
	for arch in "${JNI_ARCHS[@]}"; do
		mkdir -p tourenplaner-android-offline/libs/"${arch}"
		strip -s -o tourenplaner-android-offline/libs/"${arch}"/libjnilibosmfind.so osmfind/osmfind-android/libs/"${arch}"/libjnilibosmfind.so
	done
)

(
	echo "Building libosmfind.jar"
	cd osmfind/libosmfind/java
	ant dist
)

(
	cd tourenplaner-android-offline/libs/
	echo "Symlinking libosmfind.jar"
	ln -s ../../osmfind/libosmfind/java/dist/lib/libosmfind.jar ./
)

build_xz() {
	local ARMABI="$1"
	local COMPILER="-4.7"

	case "$ARMABI" in
	arm*)
		COMPILER=arm-linux-androideabi${COMPILER}
		CROSS_COMPILE=arm-linux-androideabi
		ARCH=arm
		CFLAGS="${CFLAGS} -fpic -ffunction-sections -funwind-tables -fstack-protector -D__ARM_ARCH_5__ -D__ARM_ARCH_5T__ -D__ARM_ARCH_5E__ -D__ARM_ARCH_5TE__ -no-canonical-prefixes"
		CFLAGS="${CFLAGS} -DNDEBUG -fomit-frame-pointer -fstrict-aliasing -funswitch-loops -finline-limit=300"
		LDFLAGS="${LDFLAGS} -no-canonical-prefixes"
		case "$ARMABI" in
		armeabi-v7a)
			CFLAGS="${CFLAGS} -march=armv7-a -mfloat-abi=softfp -mfpu=vfpv3-d16"
			LDFLAGS="${LDFLAGS} -march=armv7-a -Wl,--fix-cortex-a8"
			;;
		*)
			CFLAGS="${CFLAGS} -march=armv5te -mtune=xscale -msoft-float"
			;;
		esac
		;;
	x86*)
		COMPILER=x86${COMPILER}
		CROSS_COMPILE=i686-linux-android
		ARCH=x86
		CFLAGS="${CFLAGS} -ffunction-sections -funwind-tables -no-canonical-prefixes -fstack-protector"
		CFLAGS="${CFLAGS} -DNDEBUG -fomit-frame-pointer -fstrict-aliasing -funswitch-loops -finline-limit=300"
		LDFLAGS="${LDFLAGS} -no-canonical-prefixes"
		;;
	mips*)
		COMPILER=mipsel-linux-android${COMPILER}
		CROSS_COMPILE=mipsel-linux-android
		ARCH=mips
		CFLAGS="${CFLAGS} -fpic -fno-strict-aliasing -finline-functions -ffunction-sections -funwind-tables -no-canonical-prefixes"
		CFLAGS="${CFLAGS} -DNDEBUG -fomit-frame-pointer -fstrict-aliasing -funswitch-loops -finline-limit=300"
		LDFLAGS="${LDFLAGS} -no-canonical-prefixes"
		;;
	*)
		echo "Unknown abi ${ARMABI}"
	esac

	export CROSS_COMPILE
	export CC=${CROSS_COMPILE}-gcc
	export CXX=${CROSS_COMPILE}-g++

	export ANDROID_NDK="${ANDROID_NDK:-/opt/android-ndk}"
	export SYSROOT="${ANDROID_NDK}/platforms/android-9/arch-${ARCH}"
	export PATH="${ANDROID_NDK}/toolchains/${COMPILER}/prebuilt/linux-x86/bin:${PATH}"

	export CFLAGS="${CFLAGS} --sysroot=${SYSROOT} -O2 -g"
	export LDFLAGS

	if [ ! -e "build_${ARMABI}/Makefile" ]; then
		echo "Invalid build dir found, removing it"
		rm -rf build_${ARMABI}
	fi

	if [ ! -d "build_${ARMABI}" ]; then
		echo "Configuring xz for architecture ${ARMABI}"
		mkdir "build_${ARMABI}"
		(
			cd "build_${ARMABI}"
			../configure "--host=${CROSS_COMPILE}" \
				--disable-threads \
				--enable-encoders=lzma2 --enable-decoders=lzma1,lzma2,delta \
				--enable-shared= --enable-static=liblzma \
				--disable-nls --disable-rpath \
				--disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-lzma-links --disable-scripts
		)
	fi

	(
		echo "Building xz for architecture ${ARMABI}"
		cd "build_${ARMABI}"
		make -j4
	)
}

build_xz_jni() {
	local ARMABI="$1"

	if [ ! -e "build_${ARMABI}/Makefile" ]; then
		echo "Invalid build dir found, removing it"
		rm -rf build_${ARMABI}
	fi

	if [ ! -d "build_${ARMABI}" ]; then
		echo "Preparing xz-jni with cmake for architecture ${ARMABI}"
		mkdir "build_${ARMABI}"
		(
			cd "build_${ARMABI}"
			cmake \
				-DCMAKE_TOOLCHAIN_FILE=../cmake/android.toolchain.cmake \
				-DANDROID_ABI="${ARMABI}" \
				-DANDROID_NATIVE_API_LEVEL="android-9" \
				-DXZ_INCLUDE_DIR="../../xz/src/liblzma/api" \
				-DXZ_LIB="../../xz/build_${ARMABI}/src/liblzma/.libs/liblzma.a" \
				-DCMAKE_BUILD_TYPE="RelWithDebInfo" \
				../
		)
	fi

	(
		echo "Building xz-jni for architecture ${ARMABI}"
		cd "build_${ARMABI}"
		make -j4
	)
}

(
	cd xz

	if [ ! -x configure ]; then
		./autogen.sh
	fi

	echo "Building xz"

	for arch in "${JNI_ARCHS[@]}"; do (build_xz "${arch}"); done
)

(
	cd xz-jni
	echo "Building xz-jni"

	for arch in "${JNI_ARCHS[@]}"; do build_xz_jni "${arch}"; done
)

(
	echo "Installing stripped xz-jni libraries"
	for arch in "${JNI_ARCHS[@]}"; do
		mkdir -p tourenplaner-android-offline/libs/"${arch}"
		strip -s -o tourenplaner-android-offline/libs/"${arch}"/libxz-jni.so xz-jni/libs/"${arch}"/libxz-jni.so
	done
)

(
	echo "Building xz-jni.jar"
	cd xz-jni/java
	ant dist
)

(
	cd tourenplaner-android-offline/libs/
	echo "Symlinking xz-jni.jar"
	ln -s ../../xz-jni/java/dist/xz-jni.jar ./
)

android update project -p tourenplaner-android-offline
