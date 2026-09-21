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
  enableCuda ? stdenvNoCC.hostPlatform.isLinux,
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

in stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "bend";
  version = "2.0.24";

  src = fetchFromGitHub {
    owner = "bendlang";
    repo = "bend";
    rev = "2a7f7125cf218b6ff089c366fa8ce69e100d4a17";
    hash = "sha256-91NqfAtff1l0uf5+wXrjdi3VpdcfrNH80Cjo7b2Wf7Y=";
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
    cp -r -t $out/share/bend2 bend2/base.bend bend2/bend.ts bend2/comp.ts bend2/main.ts bend2/effs
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

  meta = {
    description = "Bend 2: a fast language that blocks AI mistakes via proof.";
    homepage = "https://bend-lang.com";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ joaomoreira ];
    mainProgram = "bend";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
