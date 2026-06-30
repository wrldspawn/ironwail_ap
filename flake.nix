{
	inputs = {
		nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
		flake-parts.url = "github:hercules-ci/flake-parts";
	};

	outputs = inputs@{flake-parts, ...}:
		flake-parts.lib.mkFlake {inherit inputs;} {
			imports = [
				inputs.flake-parts.flakeModules.easyOverlay
			];
			systems = [
				"x86_64-linux"
			];
			perSystem = {config, pkgs, ...}: {
				packages.default = pkgs.callPackage ./nix/package.nix {};
				overlayAttrs = {
					inherit (config.packages) ironwail-ap;
				};
				packages.ironwail-ap = pkgs.callPackage ./nix/package.nix {};
			};
		};
}
