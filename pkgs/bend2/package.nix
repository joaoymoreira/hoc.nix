{
  lib,
  stdenv,
  fetchFromGitHub,
  typst,
  makeWrapper,
  bun,
  clang,
  cudaPackages
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "bend";
  version = "2.0.10";

  src = fetchFromGitHub {
    owner = "bendlang";
    repo = "bend";
    rev = "2b9fc8d6e30d21ef0cd6bd122e8cf370cc8f5a8a";
    hash = "sha256-fiNTCnJwTXexEiYXe4L2gqaTxUoU6h4mVACgIZ+Lmeg=";
  };

  nativeBuildInputs = [
    typst
    makeWrapper
  ];

  buildInputs = [
    bun
    clang
    cudaPackages.cuda_cudart
    cudaPackages.cccl
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

    mkdir -p $out/{bin,share/bend2,share/doc}
    cp -r -t $out/share/bend2 bend2/base.bend bend2/bend.ts bend2/comp.ts bend2/main.ts bend2/effs
    cp -r -t $out/share/doc LICENSE bend2/docs/BendRT/BendRT.pdf bend2/docs/BendTT/BendTT.pdf
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
