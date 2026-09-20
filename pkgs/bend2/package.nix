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
  version = "2.0.18";

  src = fetchFromGitHub {
    owner = "bendlang";
    repo = "bend";
    rev = "f38a7797a98e931ae99eb49881ff4bef127b34ca";
    hash = "sha256-xiMdZ5cb6OkKEr5lPWyHIef5ELE5HAh558UUghLf4IM=";
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

    mkdir -p $out/{bin,share/bend2,share/doc,share/doc/media}
    cp -r -t $out/share/bend2 bend2/base.bend bend2/bend.ts bend2/comp.ts bend2/main.ts bend2/effs
    cp -r -t $out/share/doc LICENSE CHANGELOG.md README.md bend2/docs/BendRT/BendRT.pdf bend2/docs/BendTT/BendTT.pdf
    cp -r -t $out/share/doc/media media/*.gif
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
