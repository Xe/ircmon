{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  buildInputs = with pkgs;
    with perl532Packages; [
      perl
      IRCUtils
      DBI
      DBDSQLite
      Dotenv
      IOSocketSSL
    ];
}
