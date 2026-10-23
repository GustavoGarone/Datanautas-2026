{
  description = "Datanautas: análise reproduzível de desvínculo anual com GLMM";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/687f05a9184cad4eaf905c48b63649e3a86f5433";
  outputs = { self, nixpkgs }: let
    systems = [ "x86_64-linux" "aarch64-linux" ];
  in {
    devShells = nixpkgs.lib.genAttrs systems (system: let
      pkgs = import nixpkgs { inherit system; };
      analysisR = pkgs.rWrapper.override {
        packages = with pkgs.rPackages; [ glmmTMB nanoparquet data_table ggplot2 jsonlite gamlss knitr rmarkdown ];
      };
    in {
      default = pkgs.mkShell {
        packages = [ analysisR pkgs.poppler-utils pkgs.quarto ];
        OMP_NUM_THREADS = "2";
        QUARTO_R = "${analysisR}/bin/Rscript";
        OPENBLAS_NUM_THREADS = "1";
        MKL_NUM_THREADS = "1";
      };
    });
  };
}
