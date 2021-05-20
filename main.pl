use strict;
use warnings;

use DBI;
use Dotenv;
use IO::Socket::SSL qw(SSL_VERIFY_NONE);

Dotenv->load(".env");

my $servername = $ENV{"SERVERNAME"};
my $password = $ENV{"PASSWORD"};
my $nick = "xe-ircmon";

my $dbh = DBI->connect("dbi:SQLite:dbname=./ircmon.db", "", "", { RaiseError => 1 });
my $migration = $dbh->prepare(q{
CREATE TABLE IF NOT EXISTS stats
    ( server_name TEXT
    , time        INTEGER
    , current     INTEGER
    , max         INTEGER
    );
});
$migration->execute();
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

do: while(my $line=<$cl>) {
    if ($line =~ /^PING(.*)$/i) {
        print $cl "PONG $1\r\n";
        print $cl "USERS\r\n";
    }

    if ($line =~ /005/) {
        print $cl "JOIN #xeserv\r\n";
    }

    if ($line =~ /266 \S+ ([0-9]+) ([0-9]+).*/) {
        my $now = time();
        $update->execute($servername, $now, $1, $2);
        print "$servername,$now,$1,$2\n";
    }

    print $line;
}

