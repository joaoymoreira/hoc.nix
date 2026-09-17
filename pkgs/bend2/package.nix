{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  bun,
  clang,
  cudaPackages
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "bend";
  version = "2.0.4-unstable-2026-09-17";

  src = fetchFromGitHub {
    owner = "bendlang";
    repo = "bend";
    rev = "8008146ab90abb98b496fa2a6ffe555da7fb0dd5";
    hash = "sha256-E+4jA5jKzbyEqHblShBbIeqyV7BQEvgBzVdM3/vVEPc=";
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    bun
    clang
    cudaPackages.cuda_cudart
    cudaPackages.cccl
    cudaPackages.cuda_nvcc
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share/bend2,share/doc}
    cp -r -t $out/share/bend2 bend2/base.bend bend2/bend.ts bend2/comp.ts bend2/main.ts bend2/effs
    cp -r -t $out/share/doc LICENSE
    cp -r -t $out/share guide

    makeWrapper ${lib.getExe bun} $out/bin/bend \
      --add-flags "$out/share/bend2/main.ts" \
      --prefix PATH : ${lib.makeBinPath [ bun clang cudaPackages.cuda_nvcc ]}

    runHook postInstall
  '';

  meta = {
    description = "Bend 2: a fast language that blocks AI mistakes via proof.";
    homepage = "https://bend-lang.com";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ joaomoreira ];
    mainProgram = "bend";
    platforms = lib.platforms.all;
  };
})
