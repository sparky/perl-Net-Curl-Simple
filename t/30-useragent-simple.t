#
#
use strict;
use warnings;
use Test::More tests => 18;
use Net::Curl::Simple::UserAgent;

my $ua = Net::Curl::Simple::UserAgent->new();
my $got = 0;
my $curl = $ua->curl;
$curl->get( "http://google.com/", sub {
	my $curl = shift;
	$got = 1;

	ok( defined $curl->code, 'finish callback called' );
	cmp_ok( $curl->code, '==', 0, 'downloaded successfully' );
	ok( ! $curl->{in_use}, 'handle released' );
	is( ref $curl->{headers}, 'ARRAY', 'got array of headers' );
	is( ref $curl->{body}, '', 'got body scalar' );
	cmp_ok( scalar $curl->headers, '>', 3, 'got at least 3 headers' );
	cmp_ok( length $curl->content, '>', 1000, 'got some body' );
	isnt( $curl->{referer}, '', 'referer updarted' );
} );

$curl->join;

is( $got, 1, 'request did block' );

$ua->curl->get( 'http://google.com/search?q=perl', \&finish2 );
sub finish2
{
	my $curl = shift;
	$got = 2;

	ok( defined $curl->code, 'finish callback called' );
	cmp_ok( $curl->code, '==', 0, 'downloaded successfully' );
	ok( ! $curl->{in_use}, 'handle released' );
	is( ref $curl->{headers}, 'ARRAY', 'got array of headers' );
	is( ref $curl->{body}, '', 'got body scalar' );
	cmp_ok( scalar $curl->headers, '>', 3, 'got at least 3 headers' );
	cmp_ok( length $curl->content, '>', 1000, 'got some body' );
	isnt( $curl->{referer}, '', 'referer updarted' );
}

Net::Curl::Simple->join;

is( $got, 2, 'performed both requests' );
