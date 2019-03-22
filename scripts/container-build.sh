#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# This file is part of the GNU MCU Eclipse distribution.
#   (https://gnu-mcu-eclipse.github.io)
# Copyright (c) 2019 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software 
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Safety settings (see https://gist.github.com/ilg-ul/383869cbb01f61a51c4d).

if [[ ! -z ${DEBUG} ]]
then
  set ${DEBUG} # Activate the expand mode if DEBUG is anything but empty.
else
  DEBUG=""
fi

set -o errexit # Exit if command failed.
set -o pipefail # Exit if pipe failed.
set -o nounset # Exit if variable not set.

# Remove the initial space and instead use '\n'.
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Identify the script location, to reach, for example, the helper scripts.

build_script_path="$0"
if [[ "${build_script_path}" != /* ]]
then
  # Make relative path absolute.
  build_script_path="$(pwd)/$0"
fi

script_folder_path="$(dirname "${build_script_path}")"
script_folder_name="$(basename "${script_folder_path}")"

# =============================================================================

# Inner script to run inside Docker containers to build the 
# GNU MCU Eclipse ARM Embedded GCC distribution packages.

# For native builds, it runs on the host (macOS build cases,
# and development builds for GNU/Linux).

# Credits: GNU Tools for Arm Embedded Processors, version 7, by ARM.

# -----------------------------------------------------------------------------

defines_script_path="${script_folder_path}/defs-source.sh"
echo "Definitions source script: \"${defines_script_path}\"."
source "${defines_script_path}"

# This file is generated by the host build script.
host_defines_script_path="${script_folder_path}/host-defs-source.sh"
echo "Host definitions source script: \"${host_defines_script_path}\"."
source "${host_defines_script_path}"

common_helper_functions_script_path="${script_folder_path}/helper/common-functions-source.sh"
echo "Common helper functions source script: \"${common_helper_functions_script_path}\"."
source "${common_helper_functions_script_path}"

container_functions_script_path="${script_folder_path}/helper/container-functions-source.sh"
echo "Container helper functions source script: \"${container_functions_script_path}\"."
source "${container_functions_script_path}"

container_libs_functions_script_path="${script_folder_path}/${CONTAINER_LIBS_FUNCTIONS_SCRIPT_NAME}"
echo "Container lib functions source script: \"${container_libs_functions_script_path}\"."
source "${container_libs_functions_script_path}"

container_app_functions_script_path="${script_folder_path}/${CONTAINER_APP_FUNCTIONS_SCRIPT_NAME}"
echo "Container app functions source script: \"${container_app_functions_script_path}\"."
source "${container_app_functions_script_path}"

# -----------------------------------------------------------------------------

if [ ! -z "#{DEBUG}" ]
then
  echo $@
fi

WITH_STRIP="y"
WITHOUT_MULTILIB=""
WITH_PDF="y"
WITH_HTML="n"
IS_DEVELOP=""
IS_DEBUG=""
LINUX_INSTALL_PATH=""

# Attempts to use 8 occasionally failed, reduce if necessary.
if [ "$(uname)" == "Darwin" ]
then
  JOBS="--jobs=$(sysctl -n hw.ncpu)"
else
  JOBS="--jobs=$(grep ^processor /proc/cpuinfo|wc -l)"
fi

while [ $# -gt 0 ]
do

  case "$1" in

    --disable-strip)
      WITH_STRIP="n"
      shift
      ;;

    --without-pdf)
      WITH_PDF="n"
      shift
      ;;

    --with-pdf)
      WITH_PDF="y"
      shift
      ;;

    --without-html)
      WITH_HTML="n"
      shift
      ;;

    --with-html)
      WITH_HTML="y"
      shift
      ;;

    --jobs)
      JOBS="--jobs=$2"
      shift 2
      ;;

    --develop)
      IS_DEVELOP="y"
      shift
      ;;

    --debug)
      IS_DEBUG="y"
      WITH_STRIP="n"
      shift
      ;;

    --linux-install-path)
      LINUX_INSTALL_PATH="$2"
      shift 2
      ;;

    # --- specific

    --disable-multilib)
      WITHOUT_MULTILIB="y"
      shift
      ;;

    *)
      echo "Unknown action/option $1"
      exit 1
      ;;

  esac

done

if [ "${IS_DEBUG}" == "y" ]
then
  WITH_STRIP="n"
fi

# -----------------------------------------------------------------------------

start_timer

detect_container

prepare_xbb_env

prepare_xbb_extras

# -----------------------------------------------------------------------------

if [ ! -z "${LINUX_INSTALL_PATH}" ]
then
  # Windows builds reuse the GNU/Linux binaries.
  if [ -x "${WORK_FOLDER_PATH}/${LINUX_INSTALL_PATH}/bin/${GCC_TARGET}-gcc" ]
  then
    PATH="${WORK_FOLDER_PATH}/${LINUX_INSTALL_PATH}/bin:${PATH}"
    echo ${PATH}
  fi
fi

APP_PREFIX_NANO="${INSTALL_FOLDER_PATH}/${APP_LC_NAME}-nano"

# The \x2C is a comma in hex; without this trick the regular expression
# that processes this string in the Makefile, silently fails and the 
# bfdver.h file remains empty.
BRANDING="${BRANDING}\x2C ${TARGET_BITS}-bit"

CFLAGS_OPTIMIZATIONS_FOR_TARGET="-ffunction-sections -fdata-sections -O2"

# https://developer.arm.com/open-source/gnu-toolchain/gnu-rm/downloads
# https://gcc.gnu.org/viewcvs/gcc/branches/ARM/

# For the main GCC version, check gcc/BASE-VER.

# -----------------------------------------------------------------------------
# Defaults. Must be present.

# Redefine to existing file names to enable patches.
BINUTILS_PATCH=""
GCC_PATCH=""
GDB_PATCH=""
HAS_WINPTHREAD=""

WITH_GDB_PY3=""

# Redefine to actual URL if the build should use the Git sources.
# Also be sure GDB_GIT_BRANCH and GDB_GIT_COMMIT are defined
GDB_GIT_URL=""

MULTILIB_FLAGS=""

# -----------------------------------------------------------------------------

BINUTILS_SRC_FOLDER_NAME="binutils"
GCC_SRC_FOLDER_NAME="gcc"
NEWLIB_SRC_FOLDER_NAME="newlib"
GDB_SRC_FOLDER_NAME="gdb"

# Redefine to "y" to create the LTO plugin links.
FIX_LTO_PLUGIN=""
if [ "${TARGET_PLATFORM}" == "darwin" ]
then
  LTO_PLUGIN_ORIGINAL_NAME="liblto_plugin.0.so"
  LTO_PLUGIN_BFD_PATH="lib/bfd-plugins/liblto_plugin.so"
elif [ "${TARGET_PLATFORM}" == "linux" ]
then
  LTO_PLUGIN_ORIGINAL_NAME="liblto_plugin.so.0.0.0"
  LTO_PLUGIN_BFD_PATH="lib/bfd-plugins/liblto_plugin.so"
elif [ "${TARGET_PLATFORM}" == "win32" ]
then
  LTO_PLUGIN_ORIGINAL_NAME="liblto_plugin-0.dll"
  LTO_PLUGIN_BFD_PATH="lib/bfd-plugins/liblto_plugin-0.dll"
fi

# Redfine it to a version based name and create new files.
README_OUT_FILE_NAME="README-out.md"

# Keep them in sync with combo archive content.
if [[ "${RELEASE_VERSION}" =~ 8\.2\.1-* ]]
then

  # https://developer.arm.com/-/media/Files/downloads/gnu-rm/8-2018q4/gcc-arm-none-eabi-8-2018-q4-major-src.tar.bz2

  GCC_COMBO_VERSION_MAJOR="8"
  GCC_COMBO_VERSION_YEAR="2018"
  GCC_COMBO_VERSION_QUARTER="q4"
  GCC_COMBO_VERSION_KIND="major"

  GCC_COMBO_VERSION="${GCC_COMBO_VERSION_MAJOR}-${GCC_COMBO_VERSION_YEAR}-${GCC_COMBO_VERSION_QUARTER}-${GCC_COMBO_VERSION_KIND}"
  GCC_COMBO_FOLDER_NAME="gcc-arm-none-eabi-${GCC_COMBO_VERSION}"
  GCC_COMBO_ARCHIVE="${GCC_COMBO_FOLDER_NAME}-src.tar.bz2"

  GCC_COMBO_URL="https://developer.arm.com/-/media/Files/downloads/gnu-rm/${GCC_COMBO_VERSION_MAJOR}-${GCC_COMBO_VERSION_YEAR}${GCC_COMBO_VERSION_QUARTER}/${GCC_COMBO_ARCHIVE}"

  MULTILIB_FLAGS="--with-multilib-list=rmprofile"

  BINUTILS_VERSION="2.31"
  # From gcc/BASE_VER. svn 267074 from LAST_UPDATED and /release.txt
  GCC_VERSION="8.2.1"
  # git: df6915f029ac9acd2b479ea898388cbd7dda4974 from /release.txt.
  NEWLIB_VERSION="3.0.0"
  # git: fe554d200d1befdc3bddc9e14f8593ea3446c351 from /release.txt
  GDB_VERSION="8.2"

  ZLIB_VERSION="1.2.8"
  GMP_VERSION="6.1.0"
  MPFR_VERSION="3.1.4"
  MPC_VERSION="1.0.3"
  ISL_VERSION="0.18"
  LIBELF_VERSION="0.8.13"
  EXPAT_VERSION="2.1.1"
  LIBICONV_VERSION="1.14"
  XZ_VERSION="5.2.3"

  PYTHON_WIN_VERSION="2.7.13"

  # Except the initial release, all other must be patched.
  if [ "${RELEASE_VERSION}" != "8.2.1-1.1" ]
  then
    # For version 8.2.1-1.2 and up.
    BINUTILS_PATCH="binutils-2.31.patch"
  fi

  if [ \( "${RELEASE_VERSION}" != "8.2.1-1.1" \) -a \
       \( "${RELEASE_VERSION}" != "8.2.1-1.2" \) ]
  then
    # For version 8.2.1-1.3 and up.
    FIX_LTO_PLUGIN="y"
    HAS_WINPTHREAD="y"

    GDB_GIT_URL="git://sourceware.org/git/binutils-gdb.git"
    GDB_GIT_BRANCH="master"
    # Latest commit from 2019-01-29.
    GDB_GIT_COMMIT="ad0f979c9df2cc3fba1f120c5e7f39e35591ed07"
    GDB_SRC_FOLDER_NAME="gdb-${GDB_VERSION}.git"

    README_OUT_FILE_NAME="README-${RELEASE_VERSION}.md"
  fi

  if [ \( "${RELEASE_VERSION}" != "8.2.1-1.1" \) -a \
       \( "${RELEASE_VERSION}" != "8.2.1-1.2" \) -a \
       \( "${RELEASE_VERSION}" != "8.2.1-1.3" \) ]
  then
    GCC_PATCH="gcc-8.2.1.patch"

    HAS_WINPTHREAD=""
  fi

  if [ "${RELEASE_VERSION}" == "8.2.1-1.5" ]
  then
    # Not yet functional.
    WITH_GDB_PY3="n" 
  fi

elif [[ "${RELEASE_VERSION}" =~ 7\.3\.1-* ]]
then

  # https://developer.arm.com/-/media/Files/downloads/gnu-rm/7-2018q2/gcc-arm-none-eabi-7-2018-q2-update-src.tar.bz2

  GCC_COMBO_VERSION_MAJOR="7"
  GCC_COMBO_VERSION_YEAR="2018"
  GCC_COMBO_VERSION_QUARTER="q2"
  GCC_COMBO_VERSION_KIND="update"

  GCC_COMBO_VERSION="${GCC_COMBO_VERSION_MAJOR}-${GCC_COMBO_VERSION_YEAR}-${GCC_COMBO_VERSION_QUARTER}-${GCC_COMBO_VERSION_KIND}"
  GCC_COMBO_FOLDER_NAME="gcc-arm-none-eabi-${GCC_COMBO_VERSION}"
  GCC_COMBO_ARCHIVE="${GCC_COMBO_FOLDER_NAME}-src.tar.bz2"

  GCC_COMBO_URL="https://developer.arm.com/-/media/Files/downloads/gnu-rm/${GCC_COMBO_VERSION_MAJOR}-${GCC_COMBO_VERSION_YEAR}${GCC_COMBO_VERSION_QUARTER}/${GCC_COMBO_ARCHIVE}"

  MULTILIB_FLAGS="--with-multilib-list=rmprofile"

  BINUTILS_VERSION="2.30"
  # From gcc/BASE_VER; svn: 261907.
  GCC_VERSION="7.3.1"
  # git: 3ccfb407af410ba7e54ea0da11ae1e40b554a6f4.
  NEWLIB_VERSION="3.0.0"
  GDB_VERSION="8.1"

  ZLIB_VERSION="1.2.8"
  GMP_VERSION="6.1.0"
  MPFR_VERSION="3.1.4"
  MPC_VERSION="1.0.3"
  ISL_VERSION="0.15"
  LIBELF_VERSION="0.8.13"
  EXPAT_VERSION="2.1.1"
  LIBICONV_VERSION="1.14"
  XZ_VERSION="5.2.3"

  PYTHON_WIN_VERSION="2.7.13"

elif [[ "${RELEASE_VERSION}" =~ 7\.2\.1-* ]]
then

  # https://developer.arm.com/-/media/Files/downloads/gnu-rm/7-2017q4/gcc-arm-none-eabi-7-2017-q4-major-src.tar.bz2

  GCC_COMBO_VERSION_MAJOR="7"
  GCC_COMBO_VERSION_YEAR="2017"
  GCC_COMBO_VERSION_QUARTER="q4"
  GCC_COMBO_VERSION_KIND="major"

  GCC_COMBO_VERSION="${GCC_COMBO_VERSION_MAJOR}-${GCC_COMBO_VERSION_YEAR}-${GCC_COMBO_VERSION_QUARTER}-${GCC_COMBO_VERSION_KIND}"
  GCC_COMBO_FOLDER_NAME="gcc-arm-none-eabi-${GCC_COMBO_VERSION}"
  GCC_COMBO_ARCHIVE="${GCC_COMBO_FOLDER_NAME}-src.tar.bz2"

  GCC_COMBO_URL="https://developer.arm.com/-/media/Files/downloads/gnu-rm/${GCC_COMBO_VERSION_MAJOR}-${GCC_COMBO_VERSION_YEAR}${GCC_COMBO_VERSION_QUARTER}/${GCC_COMBO_ARCHIVE}"

  MULTILIB_FLAGS="--with-multilib-list=rmprofile"

  BINUTILS_VERSION="2.29"
  # From gcc/BASE_VER; svn: 255204.
  GCC_VERSION="7.2.1"
  # git: 76bd5cab331a873ac422fdcb7ba5fe79abea94f0, 28 Nov 2017.
  NEWLIB_VERSION="2.9.1"
  GDB_VERSION="8.0"

  ZLIB_VERSION="1.2.8"
  GMP_VERSION="6.1.0"
  MPFR_VERSION="3.1.4"
  MPC_VERSION="1.0.3"
  ISL_VERSION="0.15"
  LIBELF_VERSION="0.8.13"
  EXPAT_VERSION="2.1.1"
  LIBICONV_VERSION="1.14"
  XZ_VERSION="5.2.3"

  PYTHON_WIN_VERSION="2.7.13"

  GDB_PATCH="gdb-${GDB_VERSION}.patch"

elif [[ "${RELEASE_VERSION}" =~ 6\.3\.1-* ]]
then

  # https://developer.arm.com/-/media/Files/downloads/gnu-rm/6-2017q2/gcc-arm-none-eabi-6-2017-q2-update-src.tar.bz2

  GCC_COMBO_VERSION_MAJOR="6"
  GCC_COMBO_VERSION_YEAR="2017"
  GCC_COMBO_VERSION_QUARTER="q2"
  GCC_COMBO_VERSION_KIND="update"

  GCC_COMBO_VERSION="${GCC_COMBO_VERSION_MAJOR}-${GCC_COMBO_VERSION_YEAR}-${GCC_COMBO_VERSION_QUARTER}-${GCC_COMBO_VERSION_KIND}"
  GCC_COMBO_FOLDER_NAME="gcc-arm-none-eabi-${GCC_COMBO_VERSION}"
  GCC_COMBO_ARCHIVE="${GCC_COMBO_FOLDER_NAME}-src.tar.bz2"

  GCC_COMBO_URL="https://developer.arm.com/-/media/Files/downloads/gnu-rm/${GCC_COMBO_VERSION_MAJOR}-${GCC_COMBO_VERSION_YEAR}${GCC_COMBO_VERSION_QUARTER}/${GCC_COMBO_ARCHIVE}"

  MULTILIB_FLAGS="--with-multilib-list=rmprofile"
  BINUTILS_VERSION="2.28"
  # From gcc/BASE_VER; svn: 249437.
  GCC_VERSION="6.3.1"
  # git: 0d79b021a4ec4e6b9aa1a9f6db0e29a137005ce7, 14 June 2017.
  NEWLIB_VERSION="2.8.0"
  GDB_VERSION="7.12"

  ZLIB_VERSION="1.2.8"
  GMP_VERSION="6.1.0"
  MPFR_VERSION="3.1.4"
  MPC_VERSION="1.0.3"
  ISL_VERSION="0.15"
  LIBELF_VERSION="0.8.13"
  EXPAT_VERSION="2.1.1"
  LIBICONV_VERSION="1.14"
  XZ_VERSION="5.2.3"

  PYTHON_WIN_VERSION="2.7.13"

else
  echo "Unsupported version ${RELEASE_VERSION}."
  exit 1
fi

# Note: The 5.x build failed with various messages.

if [ "${WITHOUT_MULTILIB}" == "y" ]
then
  MULTILIB_FLAGS="--disable-multilib"
fi

if [ "${TARGET_BITS}" == "32" ]
then
  PYTHON_WIN=python-"${PYTHON_WIN_VERSION}"
else
  PYTHON_WIN=python-"${PYTHON_WIN_VERSION}".amd64
fi

PYTHON_WIN_PACK="${PYTHON_WIN}".msi
PYTHON_WIN_URL="https://www.python.org/ftp/python/${PYTHON_WIN_VERSION}/${PYTHON_WIN_PACK}"

# -----------------------------------------------------------------------------

echo
echo "Here we go..."
echo

# Download the combo package from ARM.
download_gcc_combo

if [ "${TARGET_PLATFORM}" == "win32" ]
then
  # The Windows GDB needs some headers from the Python distribution.
  download_python_win
fi

# -----------------------------------------------------------------------------
# Build dependent libraries.

# For better control, without it some components pick the lib packed 
# inside the archive.
do_zlib

# The classical GCC libraries.
do_gmp
do_mpfr
do_mpc
do_isl

# More libraries.
do_libelf
do_expat
do_libiconv
do_xz

# -----------------------------------------------------------------------------

# The task descriptions are from the ARM build script.

# Task [III-0] /$HOST_NATIVE/binutils/
# Task [IV-1] /$HOST_MINGW/binutils/
do_binutils
# copy_dir to libs included above

if [ "${TARGET_PLATFORM}" != "win32" ]
then

  # Task [III-1] /$HOST_NATIVE/gcc-first/
  do_gcc_first

  # Task [III-2] /$HOST_NATIVE/newlib/
  do_newlib ""
  # Task [III-3] /$HOST_NATIVE/newlib-nano/
  do_newlib "-nano"

  # Task [III-4] /$HOST_NATIVE/gcc-final/
  do_gcc_final ""

  # Task [III-5] /$HOST_NATIVE/gcc-size-libstdcxx/
  do_gcc_final "-nano"

else

  # Task [IV-2] /$HOST_MINGW/copy_libs/
  copy_linux_libs

  # Task [IV-3] /$HOST_MINGW/gcc-final/
  do_gcc_final ""

fi

# Task [III-6] /$HOST_NATIVE/gdb/
# Task [IV-4] /$HOST_MINGW/gdb/
do_gdb ""
do_gdb "-py"
if [ "${WITH_GDB_PY3}" == "y" ]
then
  do_gdb "-py3"
fi

# Task [III-7] /$HOST_NATIVE/build-manual
# Nope, the build process is different.

# -----------------------------------------------------------------------------

# Task [III-8] /$HOST_NATIVE/pretidy/
# Task [IV-5] /$HOST_MINGW/pretidy/
tidy_up

# Task [III-9] /$HOST_NATIVE/strip_host_objects/
# Task [IV-6] /$HOST_MINGW/strip_host_objects/
strip_binaries

if [ "${TARGET_PLATFORM}" != "win32" ]
then
  # Task [III-10] /$HOST_NATIVE/strip_target_objects/
  strip_libs
fi

check_binaries

copy_gme_files

final_tunings

if [ \( "${TARGET_PLATFORM}" == "win32" \) -a \( ! -z "${HAS_WINPTHREAD}" \) ]
then
  copy_win_libwinpthread_dll
fi

# Task [IV-7] /$HOST_MINGW/installation/
# Nope, no setup.exe.

# Task [III-11] /$HOST_NATIVE/package_tbz2/
# Task [IV-8] /Package toolchain in zip format/
create_archive

# Change ownership to non-root Linux user.
fix_ownership

# -----------------------------------------------------------------------------

stop_timer

exit 0

# -----------------------------------------------------------------------------
