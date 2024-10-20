{
  lib,
  stdenv,
  zig_0_13,
  xdg-utils,
  optimize ? "Debug",
  ...
}: let
  src = ../.;

  zig-hook = zig_0_13.hook.overrideAttrs {
    zig_default_flags = "-Dcpu=baseline -Doptimize=${optimize}";
  };

  zigCacheHash = import ./zigCacheHash.nix;

  zigCache = stdenv.mkDerivation {
    inherit src;

    pname = "vbox-manager-api-cache";
    nativeBuildInputs = [
      git
      zig-hook
    ];

    dontConfigure = true;
    dontUseZigInstall = true;
    dontUseZigBuild = true;
    dontFixup = true;

    buildPhase = ''
      runHook preBuild

      sh ./nix/build-support/fetch-zig-cache.sh

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      cp -r --reflink=auto $ZIG_GLOBAL_CACHE_DIR $out

      runHook postInstall
    '';

    outputHashMode = "recursive";
    outputHash = zigCacheHash;
  };
in stdenv.mkDerivation {
  pname = "vbox-manager-api";
  version = "0.1.0";

  inherit src;

  nativeBuildInputs = [
    zig-hook
  ];

  buildInputs = [
    xdg-utils
  ];

  dontConfigure = true;

  preBuild = ''
    rm -rf $ZIG_GLOBAL_CACHE_DIR
    cp -r --reflink=auto ${zigCache} $ZIG_GLOBAL_CACHE_DIR
    chmod u+rwX -R $ZIG_GLOBAL_CACHE_DIR
  '';

  meta = {
    homepage = "https://github.com/AlphaTechnolog/vbox-manager-api";
    license = lib.licenses.gpl3;
    platforms = ["x86_64-linux"];
    mainProgram = "vbox-manager-api";
  };
}