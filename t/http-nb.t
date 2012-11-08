#!perl -w

use strict;
use Test;

plan tests => 14;

require Net::HTTP::NB;
use IO::Socket::INET;
use Data::Dumper;
use IO::Select;
use Socket qw(TCP_NODELAY);
my $buf;

# bind a random TCP port for testing
my %lopts = (
    LocalAddr => "127.0.0.1",
    LocalPort => 0,
    Proto => "tcp",
    ReuseAddr => 1,
    Listen => 1024
);

my $srv = IO::Socket::INET->new(%lopts);
ok(ref($srv), "IO::Socket::INET");
my $host = $srv->sockhost . ':' . $srv->sockport;
my $nb = Net::HTTP::NB->new(Host => $host, Blocking => 0);
ok(ref($nb), "Net::HTTP::NB");
ok(IO::Select->new($nb)->can_write(3), 1);

ok($nb->write_request("GET", "/"));
my $acc = $srv->accept;
ok(ref($acc), "IO::Socket::INET");
$acc->sockopt(TCP_NODELAY, 1);
ok($acc->sysread($buf, 4096));
ok($acc->syswrite("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n"));

ok(1, IO::Select->new($nb)->can_read(3));
my @r = $nb->read_response_headers;
ok($r[0], 200);

# calling read_entity_body before response body is readable causes
# EOF to never happen eventually
ok(!defined($nb->read_entity_body($buf, 4096)) && $!{EAGAIN});

ok($acc->syswrite("hello"), 5, "server wrote response body");

ok(IO::Select->new($nb)->can_read(3), 1, "client body is readable");
ok($nb->read_entity_body($buf, 4096), 5, "client gets 5 bytes");

# this fails if we got EAGAIN from the first read_entity_body call:
ok($nb->read_entity_body($buf, 4096), 0, "client gets EOF");
