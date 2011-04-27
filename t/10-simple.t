#
#
use Test::More tests => 16;
use Net::Curl::Simple;


my $curl = Net::Curl::Simple->new();
my $result;
$curl->get( "http://google.com/", sub { shift; $result = shift } );

ok( defined $result, 'finish callback called' );
is( $result, 0, 'downloaded successfully' );
ok( ! $curl->{in_use}, 'handle released' );
is( ref $curl->{headers}, 'ARRAY', 'got array of headers' );
is( ref $curl->{body}, '', 'got body scalar' );
cmp_ok( scalar @{ $curl->{headers} }, '>', 3, 'got at least 3 headers' );
cmp_ok( length $curl->{body}, '>', 1000, 'got some body' );
isnt( $curl->{referer}, '', 'referer updarted' );

$result = undef;
$curl->get( '/search?q=perl', sub { shift; $result = shift } );

ok( defined $result, 'finish callback called' );
is( $result, 0, 'downloaded successfully' );
ok( ! $curl->{in_use}, 'handle released' );
is( ref $curl->{headers}, 'ARRAY', 'got array of headers' );
is( ref $curl->{body}, '', 'got body scalar' );
cmp_ok( scalar @{ $curl->{headers} }, '>', 3, 'got at least 3 headers' );
cmp_ok( length $curl->{body}, '>', 1000, 'got some body' );
isnt( $curl->{referer}, '', 'referer updarted' );

