{
  description = "Ruby gem flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        ruby = pkgs.ruby_3_4; # Specify version
        kubectlWithKubeconfig = pkgs.writeShellScriptBin "kubectl" ''
          #!${pkgs.bash}/bin/bash
          KUBECONFIG="$PWD/kubeconfig.yaml" ${pkgs.kubectl}/bin/kubectl "$@"
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.pkg-config # native extension discovery
          ];

          buildInputs = [
            ruby
            pkgs.libyaml # psych gem
            pkgs.openssl # openssl gem
            kubectlWithKubeconfig
          ];

          shellHook = ''
            export GEM_HOME="$PWD/.gem"
            export GEM_PATH="$GEM_HOME"
            export PATH="$GEM_HOME/bin:$PATH"
            export BUNDLE_PATH="$GEM_HOME"
            export BUNDLE_BIN="$GEM_HOME/bin"
            export KUBECONFIG="$PWD/kubeconfig.yaml"
          '';
        };
      }
    );
}

