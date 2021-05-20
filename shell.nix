{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  buildInputs = with pkgs;
    with perl532Packages; [
      perl
      DBI
      DBDSQLite
      Dotenv
      IOSocketSSL
    ];
}
