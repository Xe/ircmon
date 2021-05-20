#!/usr/bin/env nix-shell
#! nix-shell -p perl -i perl -p perl532Packages.DBI -p perl532Packages.DBDSQLite -p perl532Packages.Dotenv -p perl532Packages.IOSocketSSL

use strict;
use warnings;

use DBI;
use Dotenv;
use IO::Socket::SSL qw(SSL_VERIFY_NONE);

Dotenv->load(".env");

my $servername = $ENV{"SERVERNAME"};
my $password = $ENV{"PASSWORD"};
my $nick = "Xe-ircmon";

my $dbh = DBI->connect("dbi:SQLite:dbname=./ircmon.db", "", "", { RaiseError => 1 });
$dbh->{sqlite_see_if_its_a_number} = 1;
$dbh->do(q{
CREATE TABLE IF NOT EXISTS stats
    ( server_name TEXT
    , time        INTEGER
    , current     INTEGER
    , max         INTEGER
    );
});
my $update = $dbh->prepare("INSERT INTO stats(server_name, time, current, max) VALUES (?, ?, ?, ?)");

my $cl = IO::Socket::SSL->new(
    PeerHost => $servername,
    PeerPort => "6697",
    SSL_verifycn_name => $servername,
    SSL_verifycn_scheme => "6697",
    SSL_hostname => $servername,
    SSL_verify_mode => SSL_VERIFY_NONE,
) or die "error=$!, ssl_error=$IO::Socket::SSL::SSL_ERROR";

print $cl "PASS xe-ircmon:$password\r\n";
print $cl "NICK $nick\r\n";
print $cl "USER $nick 0 * :https://github.com/Xe/ircmon\r\n";
print $cl "PING :foobar$servername\r\n";

print "servername,time,current,max\n";

my $last = 0;

do: while(my $line=<$cl>) {
    if ($last + 600 >= time()) {
        $last = time();
        print $cl "USERS\r\n";
    }

    print $line;

    if ($line =~ /^PING(.*)$/i) {
        print $cl "PONG $1\r\n";
    }

    if ($line =~ /005/) {
        print $cl "JOIN #xeserv\r\n";
    }

    if ($line =~ /266 \S+ ([0-9]+) ([0-9]+).*/) {
        my $now = time();
        $update->execute($servername, $now, $1, $2);
        print "$servername,$now,$1,$2\n";
    }

    if ($line =~ /:(.*)!.*@(\S+) PRIVMSG (\S+) :(.*)/) {
        my $nick = $1;
        my $host = $2;
        my $target = $3;
        my $command = $4;

        print "$target ($nick) $command";

        if ($nick eq "Xe" and $host eq "user/xe" and $target eq "#xeserv" and $command =~ /!die (.*)$/) {
            print $cl "QUIT :$1";
            die $1;
        }

        if ($command =~ /^!stats/) {
            my $status = $dbh->prepare("SELECT time, current, max FROM stats ORDER BY rowid DESC LIMIT 1 WHERE server_name = ?");
            $status->execute($servername);
            while (my @row = $status->fetchrow_array) {
                my $now = localtime($row[0]);
                print $cl "PRIVMSG $target :As of $now there are $row[1] users in $servername ($row[2] max)\r\n";
            }
        }
    }
}
