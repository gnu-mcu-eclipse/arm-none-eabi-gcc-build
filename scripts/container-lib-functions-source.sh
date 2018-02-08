# -----------------------------------------------------------------------------

# Helper script used in the second edition of the GNU MCU Eclipse build 
# scripts. As the name implies, it should contain only functions and 
# should be included with 'source' by the container build scripts.

# -----------------------------------------------------------------------------


function do_zlib() 
{
  # http://zlib.net
  # http://zlib.net/fossils/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=zlib-static
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=zlib-git

  # 2013-04-28
  local zlib_version="1.2.8"
  # 2017-01-15
  # local zlib_version="1.2.11"

  zlib_folder="zlib-${zlib_version}"
  local zlib_archive="${zlib_folder}.tar.gz"
  # local zlib_url="http://zlib.net/fossils/${zlib_archive}"
  local zlib_url="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${zlib_archive}"

  local zlib_stamp_file="${BUILD_FOLDER_PATH}/${zlib_folder}/stamp-install-completed"
  if [ ! -f "${zlib_stamp_file}" ]
  then

    cd "${WORK_FOLDER_PATH}"

    download_and_extract "${zlib_url}" "${zlib_archive}" "${zlib_folder}"

    (
      if [ ! -d "${BUILD_FOLDER_PATH}/${zlib_folder}" ]
      then
        mkdir -p "${BUILD_FOLDER_PATH}/${zlib_folder}"
        # Copy the sources in the build folder.
        cp -r "${WORK_FOLDER_PATH}/${zlib_folder}"/* "${BUILD_FOLDER_PATH}/${zlib_folder}"
      fi
      cd "${BUILD_FOLDER_PATH}/${zlib_folder}"

      xbb_activate

      echo
      echo "Running zlib configure..."

      bash "./configure" --help

      export CFLAGS="${EXTRA_CFLAGS} -Wno-shift-negative-value"
      # export LDFLAGS="${EXTRA_LDFLAGS}"
    
      bash "./configure" \
        --prefix="${INSTALL_FOLDER_PATH}" \
        \
        --static \
      | tee "${INSTALL_FOLDER_PATH}/configure-zlib-output.txt"
      cp "configure.log" "${INSTALL_FOLDER_PATH}"/configure-zlib-log.txt

      echo
      echo "Running zlib make..."

      (
        # Build.
        make ${JOBS}
        make install
      ) | tee "${INSTALL_FOLDER_PATH}/make-zlib-output.txt"
    )

    touch "${zlib_stamp_file}"

  else
    echo "Library zlib already installed."
  fi
}

function do_gmp() 
{
  # https://gmplib.org
  # https://gmplib.org/download/gmp/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gmp-hg

  # 01-Nov-2015
  local gmp_version="6.1.0"
  # 16-Dec-2016
  # local gmp_version="6.1.2"

  gmp_folder="gmp-${gmp_version}"
  local gmp_archive="${gmp_folder}.tar.xz"
  # local gmp_url="https://gmplib.org/download/gmp/${gmp_archive}"
  local gmp_url="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${gmp_archive}"

  local gmp_stamp_file="${BUILD_FOLDER_PATH}/${gmp_folder}/stamp-install-completed"
  if [ ! -f "${gmp_stamp_file}" ]
  then

    cd "${WORK_FOLDER_PATH}"

    download_and_extract "${gmp_url}" "${gmp_archive}" "${gmp_folder}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${gmp_folder}"
      cd "${BUILD_FOLDER_PATH}/${gmp_folder}"

      xbb_activate

      if [ ! -f "config.status" ]
      then 

        echo
        echo "Running gmp configure..."

        # ABI is mandatory, otherwise configure fails on 32-bits.
        # (see https://gmplib.org/manual/ABI-and-ISA.html)

        bash "${WORK_FOLDER_PATH}/${gmp_folder}/configure" --help

        export CFLAGS="-Wno-unused-value -Wno-empty-translation-unit -Wno-tautological-compare"
        export CPPFLAGS="${EXTRA_CPPFLAGS}"
        export LDFLAGS="${EXTRA_LDFLAGS}"
        export ABI="${TARGET_BITS}"
      
        bash "${WORK_FOLDER_PATH}/${gmp_folder}/configure" \
          --prefix="${INSTALL_FOLDER_PATH}" \
          \
          --build=${BUILD} \
          --host=${HOST} \
          --target=${TARGET} \
          \
          --disable-shared \
          --enable-static \
          --enable-cxx \
          --disable-nls \
        | tee "${INSTALL_FOLDER_PATH}/configure-gmp-output.txt"
        cp "config.log" "${INSTALL_FOLDER_PATH}"/config-gmp-log.txt

      fi

      echo
      echo "Running gmp make..."

      (
        # Build.
        make ${JOBS}
        make install-strip
      ) | tee "${INSTALL_FOLDER_PATH}/make-gmp-output.txt"
    )

    touch "${gmp_stamp_file}"

  else
    echo "Library gmp already installed."
  fi
}

function do_mpfr()
{
  # http://www.mpfr.org
  # http://www.mpfr.org/history.html
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/mpfr

  # 6 March 2016
  local mpfr_version="3.1.4"
  # 7 September 2017
  # local mpfr_version="3.1.6"

  mpfr_folder="mpfr-${mpfr_version}"
  local mpfr_archive="${mpfr_folder}.tar.xz"
  # local mpfr_url="http://www.mpfr.org/${mpfr_folder}/${mpfr_archive}"
  local mpfr_url="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${mpfr_archive}"

  local mpfr_stamp_file="${BUILD_FOLDER_PATH}/${mpfr_folder}/stamp-install-completed"
  if [ ! -f "${mpfr_stamp_file}" ]
  then

    cd "${WORK_FOLDER_PATH}"

    download_and_extract "${mpfr_url}" "${mpfr_archive}" "${mpfr_folder}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${mpfr_folder}"
      cd "${BUILD_FOLDER_PATH}/${mpfr_folder}"

      xbb_activate

      if [ ! -f "config.status" ]
      then 

        echo
        echo "Running mpfr configure..."

        bash "${WORK_FOLDER_PATH}/${mpfr_folder}/configure" --help

        export CFLAGS="${EXTRA_CFLAGS}"
        export CPPFLAGS="${EXTRA_CPPFLAGS}"
        export LDFLAGS="${EXTRA_LDFLAGS_LIB}"

        bash "${WORK_FOLDER_PATH}/${mpfr_folder}/configure" \
          --prefix="${INSTALL_FOLDER_PATH}" \
          \
          --build=${BUILD} \
          --host=${HOST} \
          --target=${TARGET} \
          \
          --disable-warnings \
          --disable-shared \
          --enable-static \
          --disable-nls \
        | tee "${INSTALL_FOLDER_PATH}/configure-mpfr-output.txt"
        cp "config.log" "${INSTALL_FOLDER_PATH}"/config-mpfr-log.txt

      fi

      echo
      echo "Running mpfr make..."

      (
        # Build.
        make ${JOBS}
        make install-strip
      ) | tee "${INSTALL_FOLDER_PATH}/make-mpfr-output.txt"
    )
    touch "${mpfr_stamp_file}"

  else
    echo "Library mpfr already installed."
  fi
}

function do_mpc()
{
  # http://www.multiprecision.org/
  # ftp://ftp.gnu.org/gnu/mpc
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/libmpc

  # 20 Feb 2015
  local mpc_version="1.0.3"

  mpc_folder="mpc-${mpc_version}"
  local mpc_archive="${mpc_folder}.tar.gz"
  local mpc_url="ftp://ftp.gnu.org/gnu/mpc/${mpc_archive}"

  local mpc_stamp_file="${BUILD_FOLDER_PATH}/${mpc_folder}/stamp-install-completed"
  if [ ! -f "${mpc_stamp_file}" ]
  then

    cd "${WORK_FOLDER_PATH}"

    download_and_extract "${mpc_url}" "${mpc_archive}" "${mpc_folder}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${mpc_folder}"
      cd "${BUILD_FOLDER_PATH}/${mpc_folder}"

      xbb_activate

      if [ ! -f "config.status" ]
      then 

        echo
        echo "Running mpc configure..."
      
        bash "${WORK_FOLDER_PATH}/${mpc_folder}/configure" --help

        export CFLAGS="${EXTRA_CFLAGS} -Wno-unused-value -Wno-empty-translation-unit -Wno-tautological-compare"
        export CPPFLAGS="${EXTRA_CPPFLAGS}"
        export LDFLAGS="${EXTRA_LDFLAGS_LIB}"

        bash "${WORK_FOLDER_PATH}/${mpc_folder}/configure" \
          --prefix="${INSTALL_FOLDER_PATH}" \
          \
          --build=${BUILD} \
          --host=${HOST} \
          --target=${TARGET} \
          \
          --disable-shared \
          --enable-static \
          --disable-nls \
        | tee "${INSTALL_FOLDER_PATH}/configure-mpc-output.txt"
        cp "config.log" "${INSTALL_FOLDER_PATH}"/config-mpc-log.txt

      fi

      echo
      echo "Running mpc make..."

      (
        # Build.
        make ${JOBS}
        make install-strip
      ) | tee "${INSTALL_FOLDER_PATH}/make-mpc-output.txt"
    )
    touch "${mpc_stamp_file}"

  else
    echo "Library mpc already installed."
  fi
}

function do_isl()
{
  # http://isl.gforge.inria.fr
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=isl

  # 2015-06-12
  local isl_version="0.15"
  # 2016-01-15
  # local isl_version="0.16.1"
  # 2016-12-20
  # local isl_version="0.18"

  isl_folder="isl-${isl_version}"
  local isl_archive="${isl_folder}.tar.xz"
  # local isl_url="http://isl.gforge.inria.fr/${isl_archive}"
  local isl_url="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${isl_archive}"

  local isl_stamp_file="${BUILD_FOLDER_PATH}/${isl_folder}/stamp-install-completed"
  if [ ! -f "${isl_stamp_file}" ]
  then

    cd "${WORK_FOLDER_PATH}"

    download_and_extract "${isl_url}" "${isl_archive}" "${isl_folder}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${isl_folder}"
      cd "${BUILD_FOLDER_PATH}/${isl_folder}"

      xbb_activate

      if [ ! -f "config.status" ]
      then 

        echo
        echo "Running isl configure..."

        bash "${WORK_FOLDER_PATH}/${isl_folder}/configure" --help

        export CFLAGS="${EXTRA_CFLAGS} -Wno-dangling-else"
        export CPPFLAGS="${EXTRA_CPPFLAGS}"
        export LDFLAGS="${EXTRA_LDFLAGS_LIB}"

        bash "${WORK_FOLDER_PATH}/${isl_folder}/configure" \
          --prefix="${INSTALL_FOLDER_PATH}" \
          \
          --build=${BUILD} \
          --host=${HOST} \
          --target=${TARGET} \
          \
          --disable-shared \
          --enable-static \
          --disable-nls \
        | tee "${INSTALL_FOLDER_PATH}/configure-isl-output.txt"
        cp "config.log" "${INSTALL_FOLDER_PATH}"/config-isl-log.txt

      fi

      echo
      echo "Running isl make..."

      (
        # Build.
        make ${JOBS}
        make install-strip
      ) | tee "${INSTALL_FOLDER_PATH}/make-isl-output.txt"

    )
    touch "${isl_stamp_file}"

  else
    echo "Library isl already installed."
  fi
}

function do_libelf()
{
  # http://www.mr511.de/
  # http://www.mr511.de/software/

  local libelf_version="0.8.13"

  libelf_folder="libelf-${libelf_version}"
  local libelf_archive="${libelf_folder}.tar.gz"
  # local libelf_url="http://www.mr511.de/software/${libelf_archive}"
  local libelf_url="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${libelf_archive}"

  local libelf_stamp_file="${BUILD_FOLDER_PATH}/${libelf_folder}/stamp-install-completed"
  if [ ! -f "${libelf_stamp_file}" ]
  then

    cd "${WORK_FOLDER_PATH}"

    download_and_extract "${libelf_url}" "${libelf_archive}" "${libelf_folder}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${libelf_folder}"
      cd "${BUILD_FOLDER_PATH}/${libelf_folder}"

      xbb_activate

      if [ ! -f "config.status" ]
      then 

        echo
        echo "Running libelf configure..."

        bash "${WORK_FOLDER_PATH}/${libelf_folder}/configure" --help

        export CFLAGS="${EXTRA_CFLAGS} -Wno-tautological-compare"
        export CPPFLAGS="${EXTRA_CPPFLAGS}"
        export LDFLAGS="${EXTRA_LDFLAGS}"

        bash "${WORK_FOLDER_PATH}/${libelf_folder}/configure" \
          --prefix="${INSTALL_FOLDER_PATH}" \
          \
          --build=${BUILD} \
          --host=${HOST} \
          --target=${TARGET} \
          \
          --disable-shared \
          --enable-static \
          --disable-nls \
        | tee "${INSTALL_FOLDER_PATH}/configure-libelf-output.txt"
        cp "config.log" "${INSTALL_FOLDER_PATH}"/config-libelf-log.txt

      fi

      echo
      echo "Running libelf make..."

      (
        # Build.
        make ${JOBS}
        make install
      ) | tee "${INSTALL_FOLDER_PATH}/make-libelf-output.txt"
    )

    touch "${libelf_stamp_file}"

  else
    echo "Library libelf already installed."
  fi
}

function do_expat()
{
  # https://libexpat.github.io
  # https://github.com/libexpat/libexpat/releases
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=expat-git

  # Oct 21, 2017
  local expat_version="2.1.1"
  # Nov 1, 2017
  # local expat_version="2.2.5"

  expat_folder="expat-${expat_version}"
  local expat_archive="${expat_folder}.tar.bz2"
  local expat_release="R_$(echo ${expat_version} | sed -e 's|[.]|_|g')"
  local expat_url="https://github.com/libexpat/libexpat/releases/download/${expat_release}/${expat_archive}"

  local expat_stamp_file="${BUILD_FOLDER_PATH}/${expat_folder}/stamp-install-completed"
  if [ ! -f "${expat_stamp_file}" ]
  then

    cd "${WORK_FOLDER_PATH}"

    download_and_extract "${expat_url}" "${expat_archive}" "${expat_folder}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${expat_folder}"
      cd "${BUILD_FOLDER_PATH}/${expat_folder}"

      xbb_activate

      if [ ! -f "config.status" ]
      then 

        echo
        echo "Running expat configure..."

        bash "${WORK_FOLDER_PATH}/${expat_folder}/configure" --help

        export CFLAGS="${EXTRA_CFLAGS}"
        export CPPFLAGS="${EXTRA_CPPFLAGS}"
        export LDFLAGS="${EXTRA_LDFLAGS}"

        bash "${WORK_FOLDER_PATH}/${expat_folder}/configure" \
          --prefix="${INSTALL_FOLDER_PATH}" \
          \
          --build=${BUILD} \
          --host=${HOST} \
          --target=${TARGET} \
          \
          --disable-shared \
          --enable-static \
          --disable-nls \
        | tee "${INSTALL_FOLDER_PATH}/configure-expat-output.txt"
        cp "config.log" "${INSTALL_FOLDER_PATH}"/config-expat-log.txt

      fi

      echo
      echo "Running expat make..."

      (
        # Build.
        make ${JOBS}
        make install
      ) | tee "${INSTALL_FOLDER_PATH}/make-expat-output.txt"

    )

    touch "${expat_stamp_file}"

  else
    echo "Library expat already installed."
  fi
}

function do_libiconv()
{
  # https://www.gnu.org/software/libiconv/
  # https://ftp.gnu.org/pub/gnu/libiconv/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=libiconv

  # 2011-08-07
  local libiconv_version="1.14"
  # 2017-02-02
  # local libiconv_version="1.15"

  libiconv_folder="libiconv-${libiconv_version}"
  local libiconv_archive="${libiconv_folder}.tar.gz"
  local libiconv_url="https://ftp.gnu.org/pub/gnu/libiconv/${libiconv_archive}"

  local libiconv_stamp_file="${BUILD_FOLDER_PATH}/${libiconv_folder}/stamp-install-completed"
  if [ ! -f "${libiconv_stamp_file}" ]
  then

    cd "${WORK_FOLDER_PATH}"

    download_and_extract "${libiconv_url}" "${libiconv_archive}" "${libiconv_folder}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${libiconv_folder}"
      cd "${BUILD_FOLDER_PATH}/${libiconv_folder}"

      xbb_activate

      if [ ! -f "config.status" ]
      then 

        echo
        echo "Running libiconv configure..."

        bash "${WORK_FOLDER_PATH}/${libiconv_folder}/configure" --help

        export CFLAGS="${EXTRA_CFLAGS} -Wno-tautological-compare -Wno-parentheses-equality -Wno-static-in-inline"
        export CPPFLAGS="${EXTRA_CPPFLAGS}"
        export LDFLAGS="${EXTRA_LDFLAGS}"

        bash "${WORK_FOLDER_PATH}/${libiconv_folder}/configure" \
          --prefix="${INSTALL_FOLDER_PATH}" \
          \
          --build=${BUILD} \
          --host=${HOST} \
          --target=${TARGET} \
          \
          --disable-shared \
          --enable-static \
          --disable-nls \
        | tee "${INSTALL_FOLDER_PATH}/configure-libiconv-output.txt"
        cp "config.log" "${INSTALL_FOLDER_PATH}"/config-libiconv-log.txt

      fi

      echo
      echo "Running libiconv make..."

      (
        # Build.
        make ${JOBS}
        make install-strip
      ) | tee "${INSTALL_FOLDER_PATH}/make-libiconv-output.txt"
    )

    touch "${libiconv_stamp_file}"

  else
    echo "Library libiconv already installed."
  fi
}

function do_xz()
{
  # https://tukaani.org/xz/
  # https://sourceforge.net/projects/lzmautils/files/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=xz-git

  # 2016-12-30
  local xz_version="5.2.3"

  xz_folder="xz-${xz_version}"
  local xz_archive="${xz_folder}.tar.xz"
  # local xz_url="https://sourceforge.net/projects/lzmautils/files/${xz_archive}"
  local xz_url="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${xz_archive}"

  local xz_stamp_file="${BUILD_FOLDER_PATH}/${xz_folder}/stamp-install-completed"
  if [ ! -f "${xz_stamp_file}" ]
  then

    cd "${WORK_FOLDER_PATH}"

    download_and_extract "${xz_url}" "${xz_archive}" "${xz_folder}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${xz_folder}"
      cd "${BUILD_FOLDER_PATH}/${xz_folder}"

      xbb_activate

      if [ ! -f "config.status" ]
      then 

        echo
        echo "Running xz configure..."

        bash "${WORK_FOLDER_PATH}/${xz_folder}/configure" --help

        export CFLAGS="${EXTRA_CFLAGS} -Wno-implicit-fallthrough"
        export CPPFLAGS="${EXTRA_CPPFLAGS}"
        export LDFLAGS="${EXTRA_LDFLAGS}"

        bash "${WORK_FOLDER_PATH}/${xz_folder}/configure" \
          --prefix="${INSTALL_FOLDER_PATH}" \
          \
          --build=${BUILD} \
          --host=${HOST} \
          --target=${TARGET} \
          \
          --disable-shared \
          --enable-static \
          --disable-rpath \
          --disable-nls \
        | tee "${INSTALL_FOLDER_PATH}/configure-xz-output.txt"
        cp "config.log" "${INSTALL_FOLDER_PATH}"/config-xz-log.txt

      fi

      echo
      echo "Running xz make..."

      (
        # Build.
        make ${JOBS}
        make install-strip
      ) | tee "${INSTALL_FOLDER_PATH}/make-xz-output.txt"
    )

    touch "${xz_stamp_file}"

  else
    echo "Library xz already installed."
  fi
}
