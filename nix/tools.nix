{ pkgs }:

let
  jsDebug = pkgs.vscode-js-debug;
  codeLLDB = pkgs.vscode-extensions.vadimcn.vscode-lldb;
in
{
  packages = with pkgs; [
    # Core navigation and source-control tools.
    curl
    fd
    git
    lazygit
    ripgrep

    # Language servers.
    bash-language-server
    gopls
    graphql-language-service-cli
    lua-language-server
    marksman
    rust-analyzer
    taplo
    typescript-language-server
    vscode-langservers-extracted # CSS, HTML, JSON, and ESLint servers.
    yaml-language-server

    # Formatters, linters, parsers, and native build prerequisites.
    eslint
    gofumpt
    gotools # Includes goimports.
    hadolint
    markdownlint-cli2
    nodejs
    prettier
    prettierd
    shellcheck
    shfmt
    stylua
    tree-sitter
    typescript
    rustup # Project-selected Rust toolchains provide rustfmt and Clippy.
    gnumake
    pkg-config
    stdenv.cc

    # Test/debug support.
    delve
    jsDebug
    codeLLDB
    go
  ];

  jsDebugCommand = "${jsDebug}/bin/js-debug";
  # The adapter executable is not on PATH, so consumers must use this full path.
  codeLLDBAdapter = "${codeLLDB}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb";
}
