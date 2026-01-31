{ config, pkgs, ... }:

let
  # VS Code with extensions
  vscodeWithExtensions = pkgs.vscode-with-extensions.override {
    vscodeExtensions = with pkgs.vscode-extensions; [
      # Official extensions
      github.copilot
      bbenoist.nix
      ms-python.python
      ms-azuretools.vscode-docker
      ms-vscode-remote.remote-ssh
      rust-lang.rust-analyzer
      golang.go
      vue.volar
      bazelbuild.vscode-bazel
      ms-vscode-remote.remote-containers
      ms-kubernetes-tools.vscode-kubernetes-tools
      redhat.vscode-yaml
    ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
      # Custom extensions
      {
        name = "hardhat-solidity";
        publisher = "NomicFoundation";
        version = "0.8.25";
        sha256 = "sha256-ukNI9Co8nXzBb1wAikCHCic9p/dPNcqM13KcqTdlw6E=";
      }
      {
        name = "remote-ssh-edit";
        publisher = "ms-vscode-remote";
        version = "0.47.2";
        sha256 = "1hp6gjh4xp2m1xlm1jsdzxw9d8frkiidhph6nvl24d0h8z34w49g";
      }
      {
        name = "proto";
        publisher = "peterj";
        version = "0.0.4";
        sha256 = "O8z9VPrR/i83SeT1cF6pFiFQNLu25NmQSu9NAyjoLww=";
      }
    ];
  };

  # CUDA packages pinned to cuDNN 8.x for sm_61 (GTX 1070) compatibility
  cudaPackagesCudnn8 = pkgs.cudaPackages.override (prevArgs: {
    manifests = prevArgs.manifests // {
      cudnn = pkgs._cuda.manifests.cudnn."8.9.7";
    };
  });

  # Package groups
  devTools = with pkgs; [
    git
    vim
    tmux
    gh
    bun
    codex
    postgresql
  ];

  containerTools = with pkgs; [
    docker
    nvidia-docker
    kubectl
    kubectx
    kubernetes-helm
  ];

  networkingTools = with pkgs; [
    openvpn
    socat
    net-tools
    killall
    wget
    curl
  ];

  monitoringTools = with pkgs; [
    htop
    nmon
    nload
    iftop
  ];

  desktopApps = with pkgs; [
    discord
    google-chrome
    slack
    spotify
    terminator
    libreoffice
    nemo
  ];

  cloudTools = with pkgs; [
    awscli2
  ];

  filesystemTools = with pkgs; [
    inotify-tools
    fuse
    fuse3
  ];

  databaseTools = with pkgs; [
    redisinsight
  ];

  utilityTools = with pkgs; [
    jq
    openssl
    mktemp
    lz4
    zstd
  ];

  gpuTools = with pkgs; [
    rocmPackages.llvm.clang
    cudaPackagesCudnn8.cudatoolkit
    cudaPackagesCudnn8.cudnn
  ];
in
{
  environment.systemPackages =
    devTools ++
    containerTools ++
    networkingTools ++
    monitoringTools ++
    desktopApps ++
    cloudTools ++
    filesystemTools ++
    databaseTools ++
    utilityTools ++
    gpuTools ++
    [
      vscodeWithExtensions
    ];
}
