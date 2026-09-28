{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  bun,
  typst,
  clang,
  cudaPackages,
  alsa-lib,
  libx11,
  xorgproto,
  enableClang ? true,
  enableAlsa ? stdenvNoCC.hostPlatform.isLinux,
  enableX ? stdenvNoCC.hostPlatform.isLinux,
  enableCuda ? false,
  disableTelemetry ? true,
  libcudaPath ? "/run/opengl-driver/lib"
}:

let
  binPackages =
    lib.optionals enableClang [ clang ]
    ++ lib.optionals enableCuda [ cudaPackages.cuda_nvcc ];

  includePackages =
    lib.optionals enableX [ libx11.dev xorgproto ]
    ++ lib.optionals enableAlsa [ alsa-lib.dev ]
    ++ lib.optionals enableCuda [ cudaPackages.cudatoolkit ];

  libraryPackages =
    lib.optionals enableX [ libx11 ]
    ++ lib.optionals enableAlsa [ alsa-lib ]
    ++ lib.optionals enableCuda [ cudaPackages.cudatoolkit ];

  binPaths = lib.makeBinPath binPackages;
  includePaths = lib.makeSearchPath "include" includePackages;
  libraryPaths = lib.makeLibraryPath libraryPackages;

  # `-lcuda` (the CUDA driver library) is not part of the redistributable
  # toolkit: the real library is installed by the NVIDIA driver, outside the Nix
  # store. The toolkit ships only a link-time stub (SONAME libcuda.so.1) in
  # lib/stubs; the real driver satisfies it at runtime.
  stubPaths = lib.optionals enableCuda [
    "${cudaPackages.cudatoolkit}/lib/stubs"
  ];

  # Link-time search path: real libs + the libcuda stub.
  linkPaths = lib.concatStringsSep ":"
    (lib.filter (p: p != "") ([ libraryPaths ] ++ stubPaths));

  # Run-time search path: real libs + the NVIDIA driver location on NixOS.
  runtimePaths = lib.concatStringsSep ":"
    (lib.filter (p: p != "")
      ([ libraryPaths ]
       ++ lib.optionals (enableCuda && stdenvNoCC.hostPlatform.isLinux) [
         libcudaPath
       ]));

  # Linker flags for Bend-generated C: mirrors what `bend` itself passes to
  # clang, so a manual `clang main.c -o main` in the devshell links too.
  linkFlags =
    lib.optionals enableX [ "-lX11" ]
    ++ lib.optionals enableAlsa [ "-lasound" ]
    ++ lib.optionals enableCuda [ "-lcuda" "-lnvrtc" ];
in stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "bend";
  version = "2.0.32";

  src = fetchFromGitHub {
    owner = "bendlang";
    repo = "bend";
    rev = "573002f01ec6c52416d44489543f69a9625facf8";
    hash = "sha256-L3IQepAJuQaQiLZnluWgWIxdBZTMaJYipA9nis3i2BY=";
  };

  nativeBuildInputs = [
    typst
    makeWrapper
  ];

  buildInputs = [
    bun
  ] ++ lib.optionals enableClang [
    clang
  ] ++ lib.optionals enableX [
    libx11.dev
    xorgproto
  ] ++ lib.optionals enableAlsa [
    alsa-lib.dev
  ] ++ lib.optionals enableCuda [
    cudaPackages.cudatoolkit
    cudaPackages.cuda_nvcc
  ];

  buildPhase = ''
    runHook preBuild

    typst compile --root=bend2/docs/ bend2/docs/BendRT/main.typ bend2/docs/BendRT/BendRT.pdf
    typst compile --root=bend2/docs/ bend2/docs/BendTT/main.typ bend2/docs/BendTT/BendTT.pdf

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share/bend2,share/doc,share/doc/media}
    cp -r -t $out/share/bend2 bend2/*.bend bend2/*.ts bend2/*.lean bend2/effs
    cp -r -t $out/share/doc LICENSE CHANGELOG.md README.md bend2/docs/BendRT/BendRT.pdf bend2/docs/BendTT/BendTT.pdf
    cp -r -t $out/share/doc/media media/*.gif
    cp -r -t $out/share guide

    makeWrapper ${lib.getExe bun} $out/bin/bend \
      --add-flags "$out/share/bend2/main.ts" \
      ${lib.optionalString (binPaths != "") "--prefix PATH : ${binPaths}"} \
      ${lib.optionalString (includePaths != "") "--prefix CPATH : ${includePaths}"} \
      ${lib.optionalString (linkPaths != "") "--prefix LIBRARY_PATH : ${linkPaths}"} \
      ${lib.optionalString (runtimePaths != "") "--prefix LD_LIBRARY_PATH : ${runtimePaths}"} \
      ${lib.optionalString enableCuda ''--set-default CUDA_HOME "${cudaPackages.cudatoolkit}"''} \
      ${lib.optionalString disableTelemetry "--set-default BEND_NO_TELEMETRY 1"}

    runHook postInstall
  '';

  # Exposed for the devShell in flake.nix, so the shell and the wrapped
  # `bend` binary always agree on dependencies and environment.
  passthru = {
    inherit binPaths includePaths libraryPaths linkFlags;

    # The environment `makeWrapper` sets up for the `bend` binary.
    runtimeEnv =
      (lib.optionalAttrs (includePaths != "") {
        CPATH = includePaths;
      })
      // (lib.optionalAttrs (linkPaths != "") {
        LIBRARY_PATH = linkPaths;
      })
      // (lib.optionalAttrs (runtimePaths != "") {
        LD_LIBRARY_PATH = runtimePaths;
      })
      // (lib.optionalAttrs enableCuda {
        CUDA_HOME = "${cudaPackages.cudatoolkit}";
      })
      // (lib.optionalAttrs disableTelemetry {
        BEND_NO_TELEMETRY = "1";
      });
  };

  meta = {
    description = "Bend 2: a fast language that blocks AI mistakes via proof.";
    homepage = "https://bend-lang.com";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ joaomoreira ];
    mainProgram = "bend";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
