#!/usr/bin/env nix-shell
#! nix-shell -p perl -i perl -p perl532Packages.DBI -p perl532Packages.DBDSQLite

use strict;
use warnings;

use DBI;
use IO::Socket qw(AF_INET AF_UNIX SOCK_STREAM SHUT_WR);
use IO::Socket::UNIX;

my $dbh = DBI->connect("dbi:SQLite:dbname=./ircmon.db", "", "", { RaiseError => 1 });
my $status = $dbh->prepare("SELECT time, current, max FROM stats WHERE server_name = ? ORDER BY rowid DESC LIMIT 1");
my $sockpath = $ENV{"SOCKPATH"};
print "listening on $sockpath\n";

unlink($sockpath);
my $server = IO::Socket::UNIX->new(
    Type => SOCK_STREAM(),
    Local => $sockpath,
    Listen => 1,
);

my $count = 1;
while (my $conn = $server->accept()) {
    $conn->print("HTTP/1.1 200 OK\r\n");
    $conn->print("Content-Type: text/plain\r\n\r\n");

    my $servername = "irc.libera.chat";
    $status->execute($servername);
    while (my @row = $status->fetchrow_array) {
        my $then = localtime($row[0]);
        $conn->print("# as of $then\n");
        $conn->print("ircmon_current_connections{\"$servername\"} $row[1]\n");
        $conn->print("ircmon_max_connections{\"$servername\"} $row[2]\n");
    }

    $conn->shutdown(SHUT_WR);
}


