{ pkgs, lib, stdenv,
  fetchzip,
  zlib, ncurses5, python27,
}:

# Used for reference...
# https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/compilers/gcc-arm-embedded/10/default.nix

stdenv.mkDerivation rec {
  name = "lowrisc-riscv-gcc-toolchain";
  version = "20220210-1";
  src = fetchzip {
    url = "https://github.com/lowRISC/lowrisc-toolchains/releases/download/${version}/lowrisc-toolchain-gcc-rv32imc-${version}.tar.xz";
    sha256 = "1m708xfdzf3jzclm2zw51my3nryvlsfwqkgps3xxa0xnhq4ly1bl";
  };

  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true; # We will do this manually
  dontStrip = true;

  installPhase = ''
    mkdir -p $out
    cp -r * $out
  '';
  preFixup = ''
    find $out -type f ! -name ".o" | while read f; do
      patchelf "$f" > /dev/null 2>&1 || continue
      patchelf --set-interpreter $(cat ${stdenv.cc}/nix-support/dynamic-linker) "$f" || true
      patchelf --set-rpath ${lib.makeLibraryPath [ "$out" stdenv.cc.cc ncurses5 python27 ]} "$f" || true
    done
  '';

  # postFixup =
  #   let
  #     libPath =
  #       lib.makeLibraryPath [
  #         stdenv.cc.cc.lib # libstdc++
  #         zlib
  #       ];
  #   in ''
  #   PROGS="
  #     addr2line
  #     ar
  #     as
  #     c++
  #     cc
  #     c++filt
  #     cpp
  #     elfedit
  #     g++
  #     gcc
  #     gcc-5.2.0
  #     gcc-ar
  #     gcc-nm
  #     gcc-ranlib
  #     gcov
  #     gcov-tool
  #     gdb
  #     gprof
  #     ld
  #     ld.bfd
  #     nm
  #     objcopy
  #     objdump
  #     ranlib
  #     readelf
  #     size
  #     strings
  #     strip"

  #   for prog in $PROGS; do
  #     prog="$out/bin/xtensa-esp32-elf-$prog"
  #     echo "Patching $prog"
  #     patchelf \
  #       --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
  #       --set-rpath "${libPath}" \
  #       $prog
  #   done

  #   for prog in liblto_plugin.so; do
  #     prog="$out/libexec/gcc/xtensa-esp32-elf/5.2.0/$prog"
  #     echo "Patching $prog"
  #     patchelf \
  #       --set-rpath "${libPath}" \
  #       $prog
  #   done

  #   for prog in cc1 cc1plus collect2 lto1 lto-wrapper; do
  #     prog="$out/libexec/gcc/xtensa-esp32-elf/5.2.0/$prog"
  #     echo "Patching $prog"
  #     patchelf \
  #       --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
  #       --set-rpath "${libPath}" \
  #       $prog
  #   done

  #   for prog in ar as ld ld.bfd nm objcopy objdump ranlib strip; do
  #     prog="$out/xtensa-esp32-elf/bin/$prog"
  #     echo "Patching $prog"
  #     patchelf \
  #       --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
  #       --set-rpath "${libPath}" \
  #       $prog
  #   done
  # '';
}
