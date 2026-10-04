{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.azithro;

  cleanConfigSource =
    source:
    lib.cleanSourceWith {
      src = source;
      filter =
        path: _type:
        let
          relativePath = lib.removePrefix "${toString source}/" (toString path);
        in
        path == source
        || builtins.elem relativePath [
          "init.lua"
          "nvim-pack-lock.json"
          "lua"
          "after"
        ]
        || lib.hasPrefix "lua/" relativePath
        || lib.hasPrefix "after/" relativePath;
    };

  immutableConfigSource = cfg.configSource;

  configDirectory =
    if cfg.editableConfigPath == null then "${immutableConfigSource}" else cfg.editableConfigPath;

  neovimPackage = config.programs.neovim.package;
  neovimVersion = neovimPackage.version or "0";

  # Nightly overlays may set derivation.version to a source revision instead of
  # Neovim's upstream version. In that case, read the upstream CMake version.
  sourceSupportsPacklockfile =
    let
      sourceVersion = builtins.tryEval (
        let
          cmake = builtins.readFile "${neovimPackage.src}/CMakeLists.txt";
          lines = lib.splitString "\n" cmake;
          getVersionPart =
            name:
            let
              prefix = "set(NVIM_VERSION_${name} ";
              line = lib.findFirst (candidate: lib.hasPrefix prefix candidate) null lines;
            in
            if line == null then
              null
            else
              builtins.fromJSON (lib.removeSuffix ")" (lib.removePrefix prefix line));
          major = getVersionPart "MAJOR";
          minor = getVersionPart "MINOR";
        in
        major != null && minor != null && (major > 0 || minor >= 13)
      );
    in
    sourceVersion.success && sourceVersion.value;

  # A hexadecimal revision must not be compared as if it were a release version.
  neovimSupportsPacklockfile =
    if builtins.match "[0-9]+\\.[0-9]+.*" neovimVersion != null then
      lib.versionAtLeast neovimVersion "0.13"
    else
      sourceSupportsPacklockfile;

  tools = import ./tools.nix { inherit pkgs; };

  boolValue = value: if value then "1" else "0";

  optionalStitchrArgs =
    if cfg.stitchrPath == null then
      [
        "--unset"
        "AZITHRO_STITCHR_PATH"
      ]
    else
      [
        "--set"
        "AZITHRO_STITCHR_PATH"
        cfg.stitchrPath
      ];

  lockPath = "${config.xdg.stateHome}/nvim/nvim-pack-lock.json";

  lockArgs =
    if cfg.editableConfigPath == null then
      [
        "--set"
        "AZITHRO_PACK_LOCK"
        lockPath
      ]
    else
      [
        "--unset"
        "AZITHRO_PACK_LOCK"
      ];

in
{
  options.programs.azithro = {
    enable = lib.mkEnableOption "the Azithro Neovim distribution";

    configSource = lib.mkOption {
      type = lib.types.path;
      default = ../.;
      apply = cleanConfigSource;
      description = ''
        Source tree to deploy as the Neovim configuration. Immutable deployment
        keeps only init.lua, lua/, after/, and nvim-pack-lock.json in the store.
        Defaults to the Azithro repository containing this module. Set this
        explicitly when importing a separately pinned source.
      '';
    };

    editableConfigPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/home/alice/src/azithro";
      description = ''
        Optional absolute checkout path to link directly (out of the Nix store).
        When set, configSource is not used for the deployed config and the
        immutable plugin-lock environment override is removed.
      '';
    };

    experimentalUI = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Request Azithro's experimental UI through AZITHRO_EXPERIMENTAL_UI.
        This requires the Lua configuration to guard the private UI APIs.
      '';
    };

    profiling = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Azithro profiling through AZITHRO_PROFILING.";
    };

    stitchrPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/home/alice/src/tree-sitter-stitchr";
      description = ''
        Optional absolute local Stitchr grammar checkout. Null unsets
        AZITHRO_STITCHR_PATH.
      '';
    };

    ai = {
      enable = lib.mkEnableOption "Azithro's optional AI integrations";

      model = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "claude-3-7-sonnet-latest";
        description = "Model name exported as AZITHRO_AI_MODEL.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.editableConfigPath == null || lib.hasPrefix "/" cfg.editableConfigPath;
        message = "programs.azithro.editableConfigPath must be an absolute path.";
      }
      {
        assertion = cfg.stitchrPath == null || lib.hasPrefix "/" cfg.stitchrPath;
        message = "programs.azithro.stitchrPath must be an absolute path.";
      }
      {
        assertion = neovimSupportsPacklockfile;
        message = ''
          programs.azithro requires Neovim 0.13 or newer with packlockfile
          support; the selected package reports version ${neovimVersion}. Use a
          compatible pinned nightly or stable release.
        '';
      }
    ];

    programs.neovim = {
      enable = true;
      extraPackages = tools.packages;
      sideloadInitLua = true;
      initLua = ''
        vim.o.loadplugins = true
        dofile(${builtins.toJSON "${configDirectory}/init.lua"})
      '';
      extraWrapperArgs = [
        # HM runs sideloaded initLua with --cmd, before Neovim's normal init.lua.
        # Skip the normal init to avoid executing the source twice, then restore
        # plugin loading that `-u NONE` disables.
        "--add-flags"
        "-u NONE"
        "--set"
        "NVIM_APPNAME"
        "nvim"
        "--set"
        "AZITHRO_TOOL_PROVIDER"
        "nix"
        "--set"
        "AZITHRO_EXPERIMENTAL_UI"
        (boolValue cfg.experimentalUI)
        "--set"
        "AZITHRO_PROFILING"
        (boolValue cfg.profiling)
        "--set"
        "AZITHRO_AI_ENABLED"
        (boolValue cfg.ai.enable)
        "--set"
        "AZITHRO_AI_MODEL"
        cfg.ai.model
        "--set"
        "AZITHRO_JS_DEBUG_COMMAND"
        tools.jsDebugCommand
        "--set"
        "AZITHRO_CODELLDB_COMMAND"
        tools.codeLLDBAdapter
      ]
      ++ lockArgs
      ++ optionalStitchrArgs;
    };

    # This is the only config-directory link managed by the module. In
    # particular, it does not install plugins or manage Neovim's data directory.
    xdg.configFile.nvim.source =
      if cfg.editableConfigPath == null then
        immutableConfigSource
      else
        config.lib.file.mkOutOfStoreSymlink cfg.editableConfigPath;
  };
}
