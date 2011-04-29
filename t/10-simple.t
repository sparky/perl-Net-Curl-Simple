#
#
use Test::More tests => 16;
use Net::Curl::Simple;


my $curl = Net::Curl::Simple->new();
$curl->get( "http://google.com/", sub { } );

ok( defined $curl->code, 'finish callback called' );
is( $curl->code, 0, 'downloaded successfully' );
ok( ! $curl->{in_use}, 'handle released' );
is( ref $curl->{headers}, 'ARRAY', 'got array of headers' );
is( ref $curl->{body}, '', 'got body scalar' );
cmp_ok( scalar $curl->headers, '>', 3, 'got at least 3 headers' );
cmp_ok( length $curl->content, '>', 1000, 'got some body' );
isnt( $curl->{referer}, '', 'referer updarted' );

$curl->{code} = undef;
$curl->get( '/search?q=perl', sub { } );

ok( defined $curl->code, 'finish callback called' );
is( $curl->code, 0, 'downloaded successfully' );
ok( ! $curl->{in_use}, 'handle released' );
is( ref $curl->{headers}, 'ARRAY', 'got array of headers' );
is( ref $curl->{body}, '', 'got body scalar' );
cmp_ok( scalar $curl->headers, '>', 3, 'got at least 3 headers' );
cmp_ok( length $curl->content, '>', 1000, 'got some body' );
isnt( $curl->{referer}, '', 'referer updarted' );

