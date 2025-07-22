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

  # Package categories for better organization
  developmentTools = with pkgs; [
    git vim
    python3Minimal nodejs_22 pnpm yarn bun
    go rustup
    gcc14 lld pkg-config
    pre-commit
    bazelisk bazel-buildtools
    claude-code
  ];

  containerTools = with pkgs; [
    docker nvidia-docker
    kubectl kubectx kubernetes-helm
  ];

  networkingTools = with pkgs; [
    openvpn dante socat
    net-tools killall
    wget curl
  ];

  monitoringTools = with pkgs; [
    htop nmon nload iftop
  ];

  desktopApplications = with pkgs; [
    google-chrome firefox
    slack spotify
    terminator
    ledger-live-desktop
  ];

  cloudTools = with pkgs; [
    awscli2
  ];

  filesystemTools = with pkgs; [
    fuse fuse3
  ];

  databaseTools = with pkgs; [
    redisinsight
  ];

  utilityTools = with pkgs; [
    jq
    openssl
    mktemp
  ];

in
{
  environment.systemPackages = 
    developmentTools ++
    containerTools ++
    networkingTools ++
    monitoringTools ++
    desktopApplications ++
    cloudTools ++
    filesystemTools ++
    databaseTools ++
    utilityTools ++
    [
      vscodeWithExtensions
      pkgs.rocmPackages.llvm.clang
    ];
}
