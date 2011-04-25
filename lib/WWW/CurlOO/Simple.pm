package WWW::CurlOO::Simple;

use strict;
use warnings;
use WWW::CurlOO;
use WWW::CurlOO::Easy qw(/^CURLOPT_(PROXY|POSTFIELDS)/ /^CURLPROXY_/);
use Scalar::Util qw(looks_like_number);
use URI;
use URI::Escape qw(uri_escape);
use base qw(WWW::CurlOO::Easy);

our $VERSION = '0.01';

my @common_options = (
	timeout => 300,
	connecttimeout => 60,
	followlocation => 1,
	maxredirs => 50,
	ssl_verifypeer => 0,
	noprogress => 1,
	cookiefile => '',
	useragent => "WWW::CurlOO::Simple v$VERSION",
	headerfunction => \&_cb_header,
	httpheader => [
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
	eval {
		$proxytype{socks4a} = CURLPROXY_SOCKS4A();
		$proxytype{socks5host} = CURLPROXY_SOCKS5_HOSTNAME();
	};
	eval {
		$proxytype{http10} = CURLPROXY_HTTP_1_0();
	};
}

if ( WWW::CurlOO::version_info()->{features} & WWW::CurlOO::CURL_VERSION_LIBZ ) {
	push @common_options, encoding => 'gzip,deflate';
}

{
	my %optcache;

	sub setopt
	{
		my ( $easy, $opt, $val, $temp ) = @_;

		unless ( looks_like_number( $opt ) ) {
			# convert option name to option number
			unless ( exists $optcache{ $opt } ) {
				eval "\$optcache{ \$opt } = WWW::CurlOO::Easy::CURLOPT_\U$opt";
				die "unrecognized literal option: $opt\n"
					if $@;
			}
			$opt = $optcache{ $opt };
		}

		if ( $opt == CURLOPT_PROXY ) {
			# guess proxy type from proxy string
			my $type = ( $val =~ m#^([a-z0-9]+)://# );
			die "unknown proxy type $type\n"
				unless exists $proxytype{ $type };
			$easy->setopt( CURLOPT_PROXYTYPE, $proxytype{ $type }, $temp );
		} elsif ( $opt == CURLOPT_POSTFIELDS ) {
			# perl knows the size, but libcurl may be wrong
			$easy->setopt( CURLOPT_POSTFIELDSIZE, length $val, $temp );
		}

		my $stash = $easy->{options_temp};
		unless ( $temp ) {
			delete $stash->{ $opt };
			$stash = $easy->{options};
		}
		$stash->{ $opt } = $val;
		$easy->SUPER::setopt( $opt => $val );
	}
}

sub setopts
{
	my $easy = shift;

	while ( my ( $opt, $val ) = splice @_, 0, 2 ) {
		$easy->setopt( $opt => $val );
	}
}

sub setopts_temp
{
	my $easy = shift;

	while ( my ( $opt, $val ) = splice @_, 0, 2 ) {
		$easy->setopt( $opt => $val, 1 );
	}
}


{
	my %infocache;

	sub getinfo
	{
		my ( $easy, $info ) = @_;

		unless ( looks_like_number( $info ) ) {
			# convert option name to option number
			unless ( exists $infocache{ $info } ) {
				eval "\$infocache{ \$info } = WWW::CurlOO::Easy::CURLINFO_\U$info";
				die "unrecognized literal info: $info\n"
					if $@;
			}
			$info = $infocache{ $info };
		}

		$easy->SUPER::getinfo( $info );
	}
}

sub getinfos
{
	my $easy = shift;
	my @out;

	foreach my $arg ( @_ ) {
		my $ret = undef;
		eval {
			$ret = $easy->getinfo( $arg );
		};
		push @out, $ret;
	}
	return @out;
}

sub _cb_header
{
	my ( $easy, $data, $uservar ) = @_;
	{
		local $_ = $data;
		local $/ = "\r\n";
		chomp;
		push @{ $easy->{headers} }, $_;
	}
	return length $data;
}

sub new
{
	my $class = shift;

	my $easy = $class->SUPER::new(
		{
			body => '',
			headers => [],
			options => {},
			options_temp => {},
		}
	);
	# some sane defaults
	$easy->setopts(
		writeheader => \$easy->{headers},
		file => \$easy->{body},
		@common_options,
		@_,
	);

	return $easy;
}

sub _finish
{
	my ( $easy, $result ) = @_;
	$easy->{referer} = $easy->getinfo( 'effective_url' );
	$easy->{in_use} = 0;

	my $cb = $easy->{cb};
	$cb->( $easy, $result );

	my $perm = $easy->{options};
	foreach my $opt ( keys %{ $easy->{options_temp} } ) {
		my $val = $perm->{$opt};
		$easy->setopt( $opt => $val, 0 );

	}
}

sub ua
{
	return (shift)->share();
}

sub _perform
{
	my ( $easy, $uri, $cb ) = splice @_, 0, 3;
	if ( $easy->{in_use} ) {
		die "this handle is already in use\n";
	}
	if ( $easy->{referer} ) {
		$easy->setopt( referer => $easy->{referer} );
		$uri = URI->new( $uri )->abs( $easy->{referer} )->as_string;
	}

	$easy->setopts_temp( @_ ) if @_;
	$easy->setopt( url => $uri );

	$easy->{uri} = $uri;
	$easy->{cb} = $cb;
	$easy->{body} = '';
	$easy->{headers} = [];
	$easy->{in_use} = 1;

	if ( my $add = UNIVERSAL::can( 'WWW::CurlOO::Simple::Async', '_add' ) ) {
		$add->( $easy );
	} else {
		eval {
			$easy->perform();
		};
		$easy->_finish( $@ || WWW::CurlOO::Easy::CURLE_OK );
	}
	return $easy;
}

# get some uri
sub get
{
	my ( $easy, $uri, $cb ) = splice @_, 0, 3;
	$easy->_perform( $uri, $cb,
		@_,
		httpget => 1,
	);
}

# request head on some uri
sub head
{
	my ( $easy, $uri, $cb ) = splice @_, 0, 3;
	$easy->_perform( $uri, $cb,
		@_,
		nobody => 1,
	);
}

# post data to some uri
sub post
{
	my ( $easy, $uri, $cb, $post ) = splice @_, 0, 4;
	my @postopts;
	if ( not ref $post ) {
		@postopts = ( postfields => $post );
	} elsif ( UNIVERSAL::isa( $post, 'WWW::CurlOO::Form' ) ) {
		@postopts = ( httppost => $post );
	} elsif ( ref $post eq 'HASH' ) {
		# handle utf8 ?
		my $postdata = join '&',
			map { uri_escape( $_ ) . '=' . uri_escape( $post->{ $_ } ) }
			sort keys %$post;
		@postopts = ( postfields => $postdata );
	} else {
		die "don't know how to convert $post into a valid post\n";
	}
	$easy->_perform( $uri, $cb,
		@_,
		post => 1,
		@postopts
	);
}


1;

=head1 NAME

WWW::CurlOO::Simple - simplifies WWW::CurlOO::Easy interface

=head1 SYNOPSIS

 use WWW::CurlOO::Simple;

 WWW::CurlOO::Simple->new->get( $uri, \&finished );

 sub finished
 {
     my ( $curl, $result ) = @_;
     print "document body: $curl->{body}\n";

     # reuse connection to get another file
     $curl->get( '/other_file', \&finished2 );
 }

 sub finished2 { }

=head1 CONSTRUCTOR

=over

=item new( [PERMANENT_OPTIONS] )

Creates new WWW::CurlOO::Simple object.

 my $curl = WWW::CurlOO::Simple->new( timeout => 60 );

=back

=head1 METHODS

=over

=item setopt( NAME, VALUE, [TEMPORARY] )

Set some option. Either permanently or only for next request if TEMPORARY is
true.

=item setopts( PERMANENT_OPTIONS )

Set multiple options, permanently.

=item setopts_temp( TEMPORARY_OPTIONS )

Set multiple options, only for next request.

=item getinfo( NAME )

Get connection information.

 my $value = $curl->getinfo( 'effective_url' );

=item getinfos( INFO_NAMES )

Get multiple getinfo values.

 my ( $v1, $v2 ) ) $curl->getinfos( 'name1', 'name2' );

=item ua

Get parent L<WWW::CurlOO::Simple::UserAgent> object.

=item get( URI, CALLBACK, [TEMPORARY_OPTIONS] )

Issue a GET request. CALLBACK will be called upon finishing with two arguments:
WWW::CurlOO::Simple object and the result value. If URI is incomplete, full uri
will be constructed using $curl->{referer} as base. WWW::CurlOO::Simple updates
$curl->{referer} after every request. TEMPORARY_OPTIONS will be set for this
request only.

 $curl->get( "http://full.uri/", sub {
     my $curl = shift;
     my $result = shift;
     die "get() failed: $result\n" unless $result == 0;

     $curl->get( "/partial/uri", sub {} );
 } );

=item head( URI, CALLBACK, [TEMPORARY_OPTIONS] )

Issue a HEAD request. Otherwise it is exactly the same as get().

=item post( URI, CALLBACK, POST, [TEMPORARY_OPTIONS] )

Issue a POST request. POST value can be either a scalar, in which case it will
be sent literally, a HASHREF - will be uri-encoded, or a L<WWW::CurlOO::Form>
object (L<WWW::CurlOO::Simple::Form> is OK as well).

 $curl->post( $uri, \&finished,
     { username => "foo", password => "bar" }
 );

=back

=head1 OPTIONS

Options can be either CURLOPT_* values (import them from WWW::CurlOO::Easy),
or literal names, preferably in lower case, without the CURLOPT_ preffix.
For description of available options see L<curl_easy_setopt(3)>.

Names for getinfo can also be either CURLINFO_* values or literal names
without CURLINFO_ preffix.

=head1 SEE ALSO

L<WWW::CurlOO::Simple::UserAgent>
L<WWW::CurlOO::Simple::Async>
L<WWW::CurlOO::Easy>

=head1 COPYRIGHT

Copyright (c) 2011 Przemyslaw Iskra <sparky at pld-linux.org>.

This program is free software; you can redistribute it and/or
modify it under the same terms as perl itself.

=cut

# vim: ts=4:sw=4
