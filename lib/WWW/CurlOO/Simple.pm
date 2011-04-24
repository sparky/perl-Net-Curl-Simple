package WWW::CurlOO::Simple;

use strict;
use warnings;
use WWW::CurlOO qw(/^CURL_VERSION_/);
use WWW::CurlOO::Easy qw(/^CURLOPT_/ /^CURLPROXY_/);
use Scalar::Util qw(looks_like_number);
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
	CURLOPT_USERAGENT, 'WWW::CurlOO::Simple',
	CURLOPT_HEADERFUNCTION, \&_cb_header,
	CURLOPT_HTTPHEADER, [
		'Accept: */*',
	],
);

my %proxy = (
	http    => CURLPROXY_HTTP,
	http10  => CURLPROXY_HTTP_1_0,
	socks4  => CURLPROXY_SOCKS4,
	socks4a => CURLPROXY_SOCKS4A,
	socks5  => CURLPROXY_SOCKS5,
	socks   => CURLPROXY_SOCKS5,
	socks5host => CURLPROXY_SOCKS5_HOSTNAME,
);

if ( WWW::CurlOO::version_info()->{features} & CURL_VERSION_LIBZ ) {
	push @common_options, CURLOPT_ENCODING, 'gzip,deflate';
}

my %option2curlopt = map { lc $_ => eval "WWW::CurlOO::Easy::CURLOPT_\U$_" }
	qw(timeout useragent proxy interface url referer range httpheader);

sub setopt
{
	my ( $easy, $opt, $val ) = @_;
	unless ( looks_like_number( $opt ) ) {
		die "unrecognized literal option: $opt\n"
			unless exists $option2curlopt{ lc $opt };
		$opt = $option2curlopt{ lc $opt };
	}
	return $easy->SUPER::setopt( $opt => $val );
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
	my $uri = shift;

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
	$easy->setopts(
		defined $easy->{referer} ?
			(CURLOPT_REFERER, $easy->{referer}) : (),
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
		$easy->finish( $@ || 0 );
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
	$easy->_perform( $uri, $cb,
		CURLOPT_POST, 1,
		CURLOPT_POSTFIELDS, $post,
		CURLOPT_POSTFIELDSIZE, length $post,
	);
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
