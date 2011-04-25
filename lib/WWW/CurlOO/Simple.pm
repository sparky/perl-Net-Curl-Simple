package WWW::CurlOO::Simple;

use strict;
use warnings;
use WWW::CurlOO qw(/^CURL_VERSION_/);
use WWW::CurlOO::Easy qw(/^CURLOPT_/ /^CURLPROXY_/);
use Scalar::Util qw(looks_like_number);
use URI;
use URI::Escape qw(uri_escape);
use base qw(WWW::CurlOO::Easy);

our $VERSION = '0.01';

my @common_options = (
	CURLOPT_TIMEOUT, 300,
	CURLOPT_CONNECTTIMEOUT, 60,
	CURLOPT_FOLLOWLOCATION, 1,
	CURLOPT_MAXREDIRS, 50,
	CURLOPT_SSL_VERIFYPEER, 0,
	CURLOPT_NOPROGRESS, 1,
	CURLOPT_COOKIEFILE, '',
	CURLOPT_USERAGENT, "WWW::CurlOO::Simple v$VERSION",
	CURLOPT_HEADERFUNCTION, \&_cb_header,
	CURLOPT_HTTPHEADER, [
		'Accept: */*',
	],
);

my %proxytype = (
	http    => CURLPROXY_HTTP,
	socks4  => CURLPROXY_SOCKS4,
	socks5  => CURLPROXY_SOCKS5,
	socks   => CURLPROXY_SOCKS5,
);
{
	# introduced later in 7.18.0 and 7.19.4
	eval '$proxytype{socks4a} = CURLPROXY_SOCKS4A;
		$proxytype{socks5host} = CURLPROXY_SOCKS5_HOSTNAME';
	eval '$proxytype{http10} = CURLPROXY_HTTP_1_0';
}

if ( WWW::CurlOO::version_info()->{features} & CURL_VERSION_LIBZ ) {
	push @common_options, CURLOPT_ENCODING, 'gzip,deflate';
}

my %option2curlopt = map { lc $_ => eval "WWW::CurlOO::Easy::CURLOPT_\U$_" }
	qw(verbose timeout useragent proxy interface url referer range httpheader);

sub setopt
{
	my ( $easy, $opt, $val ) = @_;

	unless ( looks_like_number( $opt ) ) {
		# convert option name to option number
		die "unrecognized literal option: $opt\n"
			unless exists $option2curlopt{ lc $opt };
		$opt = $option2curlopt{ lc $opt };
	}

	if ( $opt == CURLOPT_PROXY ) {
		# guess proxy type from proxy string
		my $type = ( $val =~ m#^([a-z0-9]+)://# );
		die "unknown proxy type $type\n"
			unless exists $proxytype{ $type };
		$easy->SUPER::setopt( CURLOPT_PROXYTYPE, $proxytype{ $type } );
	} elsif ( $opt == CURLOPT_POSTFIELDS ) {
		# perl knows the size, but libcurl may be wrong
		$easy->SUPER::setopt( CURLOPT_POSTFIELDSIZE, length $val );
	}

	$easy->SUPER::setopt( $opt => $val );
}

sub setopts
{
	my $easy = shift;

	while ( my ( $opt, $val ) = splice @_, 0, 2 ) {
		$easy->setopt( $opt => $val );
	}
}

sub _cb_header
{
	my ( $easy, $data, $uservar ) = @_;
	push @{ $easy->{headers} }, $data;
	return length $data;
}

sub new
{
	my $class = shift;

	my $easy = $class->SUPER::new(
		{ body => '', headers => [] }
	);
	# some sane defaults
	$easy->setopts(
		CURLOPT_WRITEHEADER, \$easy->{headers},
		CURLOPT_FILE, \$easy->{body},
		@common_options,
		@_,
	);

	return $easy;
}

sub finish
{
	my ( $easy, $result ) = @_;
	$easy->{referer} = $easy->getinfo(
		WWW::CurlOO::Easy::CURLINFO_EFFECTIVE_URL
	);
	$easy->{in_use} = 0;

	my $cb = $easy->{cb};
	$cb->( $easy, $result );
}

sub _perform
{
	my ( $easy, $uri, $cb ) = splice @_, 0, 3;
	if ( $easy->{in_use} ) {
		die "this handle is already in use\n";
	}
	if ( $easy->{referer} ) {
		$easy->setopt( CURLOPT_REFERER, $easy->{referer} );
		$uri = URI->new( $uri )->abs( $easy->{referer} )->as_string;
	}
	$easy->setopts(
		@_,
		CURLOPT_URL, $uri,
	);
	$easy->{uri} = $uri;
	$easy->{cb} = $cb;
	$easy->{body} = '';
	$easy->{headers} = [];
	$easy->{in_use} = 1;

	if ( exists $INC{"WWW::CurlOO::Simple::Async"} ) {
		WWW::CurlOO::Simple::Async::add( $easy );
	} else {
		eval {
			$easy->perform();
		};
		$easy->finish( $@ || WWW::CurlOO::Easy::CURLE_OK );
	}
	return $easy;
}

# get some uri
sub get
{
	my ( $easy, $uri, $cb ) = @_;
	$easy->_perform( $uri, $cb,
		CURLOPT_HTTPGET, 1,
	);
}

# request head on some uri
sub head
{
	my ( $easy, $uri, $cb ) = @_;
	$easy->_perform( $uri, $cb,
		CURLOPT_NOBODY, 1,
	);
}

# post data to some uri
sub post
{
	my ( $easy, $uri, $cb, $post ) = @_;
	my @postopts;
	if ( not ref $post ) {
		@postopts = ( CURLOPT_POSTFIELDS, $post );
	} elsif ( UNIVERSAL::isa( $post, 'WWW::CurlOO::Form' ) ) {
		@postopts = ( CURLOPT_HTTPPOST, $post );
	} elsif ( ref $post eq 'HASH' ) {
		# handle utf8 ?
		my $postdata = join '&',
			map { uri_escape( $_ ) . '=' . uri_escape( $post->{ $_ } ) }
			sort keys %$post;
		@postopts = ( CURLOPT_POSTFIELDS, $postdata );
	} else {
		die "don't know how to convert $post into a valid post\n";
	}
	$easy->_perform( $uri, $cb, CURLOPT_POST, 1, @postopts );
}


1;

=head1 NAME

WWW::CurlOO::Simple - simplify WWW::CurlOO::Easy interface

=head1 SYNOPSIS

 use WWW::CurlOO::Simple;

 my $getter = WWW::CurlOO::Simple->new();
 $getter->get( $uri, \&finished );

 sub finished
 {
     my ( $curl, $result ) = @_;
     print "document body: $curl->{body}\n";
 }

=head1 NOTHING HERE

Yeah, just a stub

=cut
# vim: ts=4:sw=4
