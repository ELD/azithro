{ pkgs }:

{
  packages = with pkgs; [
    # Navigation, source control, and Mason download/extraction prerequisites.
    curl
    fd
    git
    lazygit
    ripgrep
    unzip

    # Runtimes and native build prerequisites, not Mason-managed tools.
    nodejs
    python3
    go
    rustup # Project-selected Rust toolchains provide rustfmt and Clippy.
    tree-sitter
    gnumake
    pkg-config
    stdenv.cc
  ];
}
