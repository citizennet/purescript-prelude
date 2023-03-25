{ self, ... }: {
  perSystem = { config, ... }: {
    packages.pre = config.purs-nix-build ./.;
  };
}
