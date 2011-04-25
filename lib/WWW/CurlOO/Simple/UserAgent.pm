package WWW::CurlOO::Simple::UserAgent;

use strict;
use warnings;
use WWW::CurlOO::Share qw(CURLSHOPT_SHARE /^CURL_LOCK_DATA_/);
use Scalar::Util qw(looks_like_number);
use base qw(WWW::CurlOO::Share);

our $VERSION = 0.01;

my %common_options = (
	useragent => __PACKAGE__ . " v$VERSION",
);

sub setopt
{
	my ( $share, $opt, $val ) = @_;

	$share = \%common_options
		unless ref $share;

	$share->{ $opt } = $val;
}

sub setopts
{
	my $share = shift;
	my %opts = @_;

	$share = \%common_options
		unless ref $share;

	$share->{ keys %opts } = values %opts;
}

sub new
{
	my $class = shift;

	my $share = $class->SUPER::new();

	$share->SUPER::setopt( CURLSHOPT_SHARE, CURL_LOCK_DATA_COOKIE );
	$share->SUPER::setopt( CURLSHOPT_SHARE, CURL_LOCK_DATA_DNS );
	$share->setopts( %common_options, @_ );

	return $share;
}

sub curl
{
	my $share = shift;
	require WWW::CurlOO::Simple;
	return WWW::CurlOO::Simple->new( share => $share, %$share, @_ );
}

1;

=head1 NAME

WWW::CurlOO::Simple::UserAgent - share some data between multiple WWW::CurlOO::Simple objects

=head1 SYNOPSIS

 use WWW::CurlOO::Simple::UserAgent;

 my $ua = WWW::CurlOO::Simple::UserAgent->new(
     useragent => "My::Downloader",
     proxy => "socks5:localhost:9980",
 );
 # those two requests share cookies and options set before
 $ua->curl()->get( $uri, \&finished );
 $ua->curl()->get( $uri2, \&finished );

 sub finished
 {
     my ( $curl, $result ) = @_;
     print "document body: $curl->{body}\n";
 }

=head1 NOTHING HERE

Yeah, just a stub

=cut
# vim: ts=4:sw=4
