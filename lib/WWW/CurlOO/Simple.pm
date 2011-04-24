package WWW::CurlOO::Simple;

use strict;
use warnings;
use WWW::CurlOO qw(/^CURL_VERSION_/);
use WWW::CurlOO::Easy qw(/^CURLOPT_/);
use base qw(WWW::CurlOO::Easy);

our $VERSION = '0.01';

my @common_options = (
	CURLOPT_TIMEOUT, 300,
	CURLOPT_CONNECTTIMEOUT, 60,
	CURLOPT_MAXREDIRS, 20,
	CURLOPT_FOLLOWLOCATION, 1,
	CURLOPT_SSL_VERIFYPEER, 0,
	CURLOPT_COOKIEFILE, '',
	CURLOPT_USERAGENT, 'WWW::CurlOO::Simple',
);

if ( WWW::CurlOO::version_info()->{features} & CURL_VERSION_LIBZ ) {
	push @common_options, CURLOPT_ENCODING, 'gzip,deflate';
}

sub setopts
{
	my $easy = shift;

	while ( my ( $opt, $val ) = splice @_, 0, 2 ) {
		$easy->setopt( $opt => $val );
	}
}

sub new
{
	my $class = shift;
	my $uri = shift;

	my $easy = $class->SUPER::new(
		{ body => '', headers => '' }
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
	if ( exists $INC{"WWW::CurlOO::Async"} ) {
		WWW::CurlOO::Async::add( $easy );
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
	$easy->setopt( CURLOPT_HTTPGET, 1 );
	$easy->_perform( $uri, $cb );
}

# request head on some uri
sub head
{
	my ( $easy, $uri, $cb ) = @_;
	$easy->setopt( CURLOPT_NOBODY, 1 );
	$easy->_perform( $uri, $cb );
}

# post data to some uri
sub post
{
	my ( $easy, $uri, $cb, $post ) = @_;
	$easy->setopt( CURLOPT_POST, 1 );
	$easy->setopt( CURLOPT_POSTFIELDS, $post );
	$easy->setopt( CURLOPT_POSTFIELDSIZE, length $post );
	$easy->_perform( $uri, $cb );
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
