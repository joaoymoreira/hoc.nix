{
  lib,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
  runCommand,
  # enableCuda ? config.cudaSupport,
  gcc14Stdenv,
  gcc14,
  cudaPackages
}:

let
  # customCudaPackages = cudaPackages.override {
  #   # Note: Availability depends on your nixpkgs version
  #   # stdenv = gcc14Stdenv;
  # };
  # nixpkgs' stdenv for CUDA builds: compiler pinned to a version nvcc
  # accepts (this is what nixpkgs' own CUDA packages use).
  # cudaStdenv = cudaPackages.backendStdenv;

  # effectiveStdenv = if enableCuda thenf cudaPackages.backendStdenv else stdenv;

  # build.rs emits cargo:rustc-link-search=native=$CUDA_HOME/lib64
  # (and hardcodes /usr/local/cuda/lib64 otherwise). Store paths use lib/, so
  # give it a lib64 to find.
  cudaHome = runCommand "hvm2-cuda-home" { } ''
    mkdir -p $out/lib64
    ln -s ${lib.getLib cudaPackages.cuda_cudart}/lib/*.so* $out/lib64/
  '';
in
rustPlatform.buildRustPackage.override {
  # cuda_nvcc-12 requires GCC<=14
  # stdenv = gcc14Stdenv;
  stdenv = cudaPackages.backendStdenv;
} (finalAttrs: {
  pname = "hvm2";
  version = "2.0.22-unstable-2024-08-21";
  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "higherorderco";
    repo = "hvm2";
    rev = "654276018084b8f44a22b562dd68ab18583bfb5b";
    hash = "sha256-6cm+zpzJ0d77cjOfiM/fU7TGVue6GK3Fncit67RW8bA=";
  };

  cargoHash = "sha256-nLcT+o6xrxPmQqK7FQpCqTlxOOUA1FzqRGQIypcq4fo=";

  passthru.updateScript = nix-update-script { };

  nativeBuildInputs = [
    cudaPackages.cuda_nvcc
    cudaPackages.cccl
  ];

  buildInputs = [
    gcc14
    cudaPackages.cuda_cudart
    cudaPackages.cuda_nvcc
  ];

  env = {
    # Force the `cc` crate (and therefore nvcc's -ccbin) onto gcc14.
    # Without this, HOST_CXX resolves to the default stdenv's gcc, which
    # nvcc rejects (see nvcc's "unsupported GNU version" check).
    CC = "${gcc14}/bin/gcc";
    CXX = "${gcc14}/bin/g++";
    HOST_CC = "${gcc14}/bin/gcc";
    HOST_CXX = "${gcc14}/bin/g++";

    # build.rs: cargo:rustc-link-search=native=$CUDA_HOME/lib64
    CUDA_HOME = "${cudaHome}";

    # Neither build.rs nor cc add CUDA include dirs, and nvcc only searches its
    # own include tree (crt/ & co). cuda_runtime.h lives in cuda_cudart's dev
    # output; thrust/cub in cuda_cccl. NVCC_PREPEND_FLAGS is read by nvcc
    # itself, so the cc crate doesn't need to cooperate.
    NVCC_PREPEND_FLAGS = lib.concatStringsSep " " [
      "-I${lib.getDev cudaPackages.cuda_cudart}/include"
      "-I${lib.getDev cudaPackages.cccl}/include"
      "-I${lib.getDev cudaPackages.cuda_nvcc}/include"
    ];

    # build.rs emits -L($CUDA_HOME)/lib64 but never -lcudart, and the .cu
    # objects call the runtime API — the final link needs this explicitly.
    NIX_LDFLAGS = "-lcudart";
  };

  # cc-rs picks the nvcc host compiler (-ccbin) from HOST_CXX, ahead of plain
  # CXX. Exporting here — after all of nixpkgs' env setup, in the shell cargo
  # runs build scripts from — cannot be shadowed by anything upstream. Remove
  # once the stdenv override above is confirmed to take effect on its own.
  preBuild = ''
    export HOST_CC="${gcc14}/bin/gcc"
    export HOST_CXX="${gcc14}/bin/g++"
  '';

  # Skip snapshot tests with non-deterministic thread IDs and environment differences.
  checkFlags = [
    "--skip=test_run_examples"
    "--skip=test_run_programs"
  ];

  meta = {
    description = "HVM2 (2024): a massively parallel, optimal functional runtime in Rust";
    homepage = "https://github.com/higherorderco/hvm2";
    license = lib.licenses.apsl20;
    maintainers = with lib.maintainers; [ joaomoreira ];
    mainProgram = "hvm2";
  };
})
