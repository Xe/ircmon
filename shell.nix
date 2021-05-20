{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  buildInputs = with pkgs;
    with perl532Packages; [
      perl
      CGI
      IRCUtils
      DBI
      DBDSQLite
      Dotenv
      IOSocketSSL
    ];
}
