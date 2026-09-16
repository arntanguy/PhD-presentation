{
  description = "PhD Presentation LaTeX build";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    tex-fmt.url = "github:wgunderwood/tex-fmt";
    tex-fmt.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, treefmt-nix, tex-fmt }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        treefmtEval = treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          settings.global.excludes = [ ".envrc" ];
          settings.formatter.tex-fmt = {
            command = "${tex-fmt.packages.${system}.default}/bin/tex-fmt";
            includes = [ "*.tex" "*.bib" ];
            options = [
              "--tabsize" "2"
              "--wraplen" "120"
            ];
          };
          programs = {
            mdformat.enable = true;
            nixfmt.enable = true;
          };
        };

        tex = pkgs.texlive.combine {
          inherit (pkgs.texlive)
            scheme-medium
            beamer
            listings
            graphbox
            graphics
            amsmath
            amsfonts
            upquote
            pgf
            hyperref
            biblatex
            biber
            ;
        };

        buildPresentation = pkgs.stdenvNoCC.mkDerivation {
          pname = "presentation";
          version = "1.0.0";
          src = ./.;
          buildInputs = [ tex pkgs.biber pkgs.coreutils ];

          buildPhase = ''
            mkdir -p build
            cp presentation.tex build/
            cp configurations.tex build/ || true
            cp beamerthemelirmm.sty build/ || true
            cp -r bib build/ || true
            cp -r movies build/ || true
            cp -r figures build/ || true
            cp -r logos build/ || true
            cd build

            # XXX: I could not find a single PDF reader that properly handles the videos included with the multimedia
            # package. It seems that okular dropped support for the phonon backend (at least the nix derivation does), and 
            # other pdf readers do not seem to support video either.
            # Thus for now patch \movie to \href for video links
            sed -i 's|\\movie\[[^]]*\]{[^}]*}{movies/\([^}]*\)}|\\href{run:movies/\1}{[Open video]}|g' presentation.tex

            ${tex}/bin/xelatex -interaction=nonstopmode presentation.tex || true
            ${pkgs.biber}/bin/biber presentation || true
            ${tex}/bin/xelatex -interaction=nonstopmode presentation.tex || true
            ${tex}/bin/xelatex -interaction=nonstopmode presentation.tex || true
          '';

          installPhase = ''
            mkdir -p $out
            cp presentation.pdf $out/
            cp -r movies $out/ || true
            cp -r figures $out/ || true
            cp -r logos $out/ || true
          '';
        };
      in
      {
        packages.default = buildPresentation;

        formatter = treefmtEval.config.build.wrapper;

        checks.formatting = treefmtEval.config.build.check self;

        devShells.default = pkgs.mkShell {
          buildInputs = [
            tex
            pkgs.biber
            pkgs.zathura
            pkgs.ffmpeg
          ];
          shellHook = ''
            echo "- Build with: nix build"
            echo "- Preview with:"
            echo "  $ zathura result/presentation.pdf"
            echo "  or your favorite pdf reader"
          '';
        };
      }
    );
}
