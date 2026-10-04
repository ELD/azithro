{
  nixpkgs ? <nixpkgs>,
  homeManager ? <home-manager>,
  system ? builtins.currentSystem,
  overlays ? [ ],
  homeDirectory ? "/tmp/azithro-check",
  configSource ? null,
}:

let
  pkgs = import nixpkgs { inherit system overlays; };
  lib = pkgs.lib;
  legacyLockAliases = [
    "AZITHRO_PACK_LOCKFILE"
    "AZITHRO_PACK_LOCK_PATH"
    "NVIM_PACK_LOCKFILE"
  ];
  usesNoLegacyLockAliases = args: !(builtins.any (arg: builtins.elem arg legacyLockAliases) args);

  evaluateHome =
    azithroOptions:
    import "${homeManager}/modules" {
      inherit pkgs;
      configuration = {
        imports = [ ./home-manager.nix ];

        home.username = "azithro-check";
        home.homeDirectory = homeDirectory;
        home.stateVersion = "26.05";
        nixpkgs.overlays = overlays;

        programs.azithro = {
          enable = true;
        }
        // lib.optionalAttrs (configSource != null) { inherit configSource; }
        // azithroOptions;
      };
    };

  immutable = evaluateHome { };
  editable = evaluateHome {
    editableConfigPath = "/tmp/azithro-editable";
    experimentalUI = false;
    profiling = true;
    stitchrPath = "/tmp/stitchr";
    ai.enable = true;
    ai.model = "azithro-check-model";
  };

  hasSequence =
    values: sequence:
    let
      lastStart = builtins.length values - builtins.length sequence;
      starts = if lastStart < 0 then [ ] else lib.range 0 lastStart;
    in
    builtins.any (
      start:
      lib.genList (offset: builtins.elemAt values (start + offset)) (builtins.length sequence) == sequence
    ) starts;

  baseline = import "${homeManager}/modules" {
    inherit pkgs;
    configuration = {
      home.username = "azithro-check";
      home.homeDirectory = homeDirectory;
      home.stateVersion = "26.05";
      nixpkgs.overlays = overlays;
      programs.neovim.enable = true;
    };
  };

  immutableArgs = immutable.config.programs.neovim.extraWrapperArgs;
  editableArgs = editable.config.programs.neovim.extraWrapperArgs;
  tools = import ./tools.nix { inherit pkgs; };
  immutableLock = "${immutable.config.xdg.stateHome}/nvim/nvim-pack-lock.json";
  immutableConfigDirectory = "${immutable.config.programs.azithro.configSource}";
  immutableConfigEntries = builtins.attrNames (
    builtins.readDir immutable.config.programs.azithro.configSource
  );
  requiredConfigEntries = [
    "init.lua"
    "lua"
    "nvim-pack-lock.json"
  ];
  allowedConfigEntries = requiredConfigEntries ++ [ "after" ];
  immutableLinkTarget = "${immutable.config.xdg.configFile.nvim.source}";

  assertionsSatisfied =
    evaluated:
    builtins.all (
      assertion: if assertion.assertion then true else throw assertion.message
    ) evaluated.config.assertions;
  editableConfigDirectory = editable.config.programs.azithro.editableConfigPath;

  checks =
    # The module must leave Home Manager's package selection untouched.
    assert immutable.config.programs.neovim.package == baseline.config.programs.neovim.package;
    assert editable.config.programs.neovim.package == baseline.config.programs.neovim.package;
    assert assertionsSatisfied immutable;
    assert assertionsSatisfied editable;
    assert hasSequence immutableArgs [
      "--set"
      "NVIM_APPNAME"
      "nvim"
    ];
    assert hasSequence immutableArgs [
      "--set"
      "AZITHRO_TOOL_PROVIDER"
      "nix"
    ];
    assert hasSequence immutableArgs [
      "--set"
      "AZITHRO_EXPERIMENTAL_UI"
      "1"
    ];
    assert hasSequence immutableArgs [
      "--set"
      "AZITHRO_PROFILING"
      "0"
    ];
    assert hasSequence immutableArgs [
      "--set"
      "AZITHRO_AI_ENABLED"
      "0"
    ];
    assert hasSequence immutableArgs [
      "--unset"
      "AZITHRO_STITCHR_PATH"
    ];
    assert hasSequence immutableArgs [
      "--set"
      "AZITHRO_CODELLDB_COMMAND"
      tools.codeLLDBAdapter
    ];
    assert hasSequence immutableArgs [
      "--set"
      "AZITHRO_PACK_LOCK"
      immutableLock
    ];
    assert usesNoLegacyLockAliases immutableArgs;
    assert hasSequence editableArgs [
      "--unset"
      "AZITHRO_PACK_LOCK"
    ];
    assert usesNoLegacyLockAliases editableArgs;
    assert hasSequence editableArgs [
      "--set"
      "AZITHRO_EXPERIMENTAL_UI"
      "0"
    ];
    assert hasSequence editableArgs [
      "--set"
      "AZITHRO_PROFILING"
      "1"
    ];
    assert hasSequence editableArgs [
      "--set"
      "AZITHRO_AI_ENABLED"
      "1"
    ];
    assert hasSequence editableArgs [
      "--set"
      "AZITHRO_AI_MODEL"
      "azithro-check-model"
    ];
    assert hasSequence editableArgs [
      "--set"
      "AZITHRO_STITCHR_PATH"
      "/tmp/stitchr"
    ];
    assert hasSequence immutableArgs [
      "--add-flags"
      "-u NONE"
    ];
    assert builtins.any (arg: lib.hasInfix "lua dofile(" arg) immutableArgs;
    assert lib.hasInfix
      (builtins.unsafeDiscardStringContext ''dofile("${immutableConfigDirectory}/init.lua")'')
      immutable.config.programs.neovim.initLua;
    assert lib.hasInfix
      (builtins.unsafeDiscardStringContext ''dofile("${editableConfigDirectory}/init.lua")'')
      editable.config.programs.neovim.initLua;
    # Git inputs omit an empty after/ directory; it is optional in the runtime tree.
    assert builtins.all (entry: builtins.elem entry immutableConfigEntries) requiredConfigEntries;
    assert builtins.all (entry: builtins.elem entry allowedConfigEntries) immutableConfigEntries;
    assert
      immutable.config.xdg.configFile.nvim.source == immutable.config.programs.azithro.configSource;
    assert immutableLinkTarget == immutableConfigDirectory;
    true;

in
assert checks;
{
  inherit system;
  nixpkgsVersion = pkgs.lib.version;
  homeManagerSource = toString homeManager;
  neovimVersion = immutable.config.programs.neovim.package.version;
  neovimPackage = immutable.config.programs.neovim.package;
  neovimPackageDrvPath = immutable.config.programs.neovim.package.drvPath;
  finalPackage = immutable.config.programs.neovim.finalPackage;
  finalPackageDrvPath = immutable.config.programs.neovim.finalPackage.drvPath;
  immutable = {
    lockPath = immutableLock;
    configDirectory = immutableConfigDirectory;
    linkTarget = immutableLinkTarget;
    wrapperArgs = immutableArgs;
  };
  editable = {
    configDirectory = editableConfigDirectory;
    wrapperArgs = editableArgs;
  };
}
