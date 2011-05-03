package Net::Curl::Simple;

use strict;
use warnings; no warnings 'redefine';
use Net::Curl 0.17;
use Net::Curl::Easy qw(/^CURLOPT_(PROXY|POSTFIELDS)/ /^CURLPROXY_/);
use Scalar::Util qw(looks_like_number);
use URI;
use URI::Escape qw(uri_escape);
use base qw(Net::Curl::Easy);

our $VERSION = '0.10';

use constant
	curl_features => Net::Curl::version_info()->{features};

use constant {
	can_ipv6 => ( curl_features & Net::Curl::CURL_VERSION_IPV6 ) != 0,
	can_ssl => ( curl_features & Net::Curl::CURL_VERSION_SSL ) != 0,
	can_libz => ( curl_features & Net::Curl::CURL_VERSION_LIBZ ) != 0,
	can_asynchdns => ( curl_features & Net::Curl::CURL_VERSION_ASYNCHDNS ) != 0,
	TRUE => !0,
	FALSE => !1,
};

use Net::Curl::Simple::Async;

my @common_options = (
	timeout => 300,
	connecttimeout => 60,
	followlocation => 1,
	maxredirs => 50,
	ssl_verifypeer => 0,
	noprogress => 1,
	cookiefile => '',
	useragent => __PACKAGE__ . ' v' . $VERSION,
	headerfunction => \&_cb_header,
	httpheader => [
		'Accept: */*',
	],
	( can_libz ? ( encoding => 'gzip,deflate' ) : () ),
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

{
	my %optcache;

	sub setopt
	{
		my ( $easy, $opt, $val, $temp ) = @_;

		unless ( looks_like_number( $opt ) ) {
			# convert option name to option number
			unless ( exists $optcache{ $opt } ) {
				eval "\$optcache{ \$opt } = Net::Curl::Easy::CURLOPT_\U$opt";
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
				eval "\$infocache{ \$info } = Net::Curl::Easy::CURLINFO_\U$info";
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
	$easy->{code} = $result;

	my $perm = $easy->{options};
	foreach my $opt ( keys %{ $easy->{options_temp} } ) {
		my $val = $perm->{$opt};
		$easy->setopt( $opt => $val, 0 );
	}

	my $cb = $easy->{cb};
	eval { $cb->( $easy ) } if $cb;
}

sub ua
{
	return (shift)->share();
}

sub _start_perform($);
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

	Net::Curl::Simple::Async::multi->add_handle( $easy );

	# block unless we've got a callback
	$easy->join unless $cb;

	return $easy;
}

*join = sub ($)
{
	my $easy = shift;
	if ( not ref $easy ) {
		# no object, wait for first easy that finishes
		$easy = Net::Curl::Simple::Async::multi->get_one();
		return $easy;
	} else {
		return $easy unless $easy->{in_use};
		Net::Curl::Simple::Async::multi->get_one( $easy );
		return $easy;
	}
};

# results
sub code
{
	return (shift)->{code};
}

sub headers
{
	return @{ (shift)->{headers} };
}

sub content
{
	return (shift)->{body};
}

# get some uri
sub get
{
	my ( $easy, $uri ) = splice @_, 0, 2;
	my $cb = pop;

	$easy->_perform( $uri, $cb,
		@_,
		httpget => 1,
	);
}

# request head on some uri
sub head
{
	my ( $easy, $uri ) = splice @_, 0, 2;
	my $cb = pop;

	$easy->_perform( $uri, $cb,
		@_,
		nobody => 1,
	);
}

# post data to some uri
sub post
{
	my ( $easy, $uri, $post ) = splice @_, 0, 3;
	my $cb = pop;

	my @postopts;
	if ( not ref $post ) {
		@postopts = ( postfields => $post );
	} elsif ( UNIVERSAL::isa( $post, 'Net::Curl::Form' ) ) {
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

# put some data
sub put
{
	my ( $easy, $uri, $put ) = splice @_, 0, 3;
	my $cb = pop;

	my @putopts;
	if ( not ref $put ) {
		die "Cannot put file $put\n"
			unless -r $put;
		open my $fin, '<', $put;
		@putopts = (
			readfunction => sub {
				my ( $easy, $maxlen, $uservar ) = @_;
				sysread $fin, my ( $r ), $maxlen;
				return \$r;
			},
			infilesize => -s $put
		);
	} elsif ( ref $put eq 'SCALAR' ) {
		my $data = $$put;
		use bytes;
		@putopts = (
			readfunction => sub {
				my ( $easy, $maxlen, $uservar ) = @_;
				my $r = substr $data, 0, $maxlen, '';
				return \$r;
			},
			infilesize => length $data
		);
	} elsif ( ref $put eq 'CODE' ) {
		@putopts = (
			readfunction => $put,
		);
	} else {
		die "don't know how to put $put\n";
	}
	$easy->_perform( $uri, $cb,
		@_,
		put => 1,
		@putopts
	);
}


1;

__END__

=head1 NAME

Net::Curl::Simple - simplifies Net::Curl::Easy interface

=head1 SYNOPSIS

 use Net::Curl::Simple;

 Net::Curl::Simple->new->get( $uri, \&finished );

 # wait until all requests are finished
 1 while Net::Curl::Simple->join;

 sub finished
 {
     my $curl = shift;
     print "document body: $curl->{body}\n";

     # reuse connection to get another file
     $curl->get( '/other_file', \&finished2 );
 }

 sub finished2 { }

=head1 WARNING

B<This module is under heavy development.> Its interface may change yet.

B<Documentation may not be up to date with latest interface changes.>

=head1 DESCRIPTION

C<Net::Curl::Simple> is a thin layer over L<Net::Curl>. It simplifies
many common tasks, while providing access to full power of L<Net::Curl>
when its needed.

L<Net::Curl> excells in asynchronous operations, thanks to a great design of
L<libcurl(3)>. To take advantage of that power C<Net::Curl::Simple> interface
uses callbacks even in synchronous mode, this should allow to quickly switch
to async when the time comes.

=head1 CONSTRUCTOR

=over

=item new( [PERMANENT_OPTIONS] )

Creates new Net::Curl::Simple object.

 my $curl = Net::Curl::Simple->new( timeout => 60 );

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

Get parent L<Net::Curl::Simple::UserAgent> object.

=item get( URI, [TEMPORARY_OPTIONS], CALLBACK )

Issue a GET request. CALLBACK will be called upon finishing with two arguments:
Net::Curl::Simple object and the result value. If URI is incomplete, full uri
will be constructed using $curl->{referer} as base. Net::Curl::Simple updates
$curl->{referer} after every request. TEMPORARY_OPTIONS will be set for this
request only.

 $curl->get( "http://full.uri/", sub {
     my $curl = shift;
     my $result = $curl->code;
     die "get() failed: $result\n" unless $result == 0;

     $curl->get( "/partial/uri", sub {} );
 } );

=item head( URI, [TEMPORARY_OPTIONS], CALLBACK )

Issue a HEAD request. Otherwise it is exactly the same as get().

=item post( URI, POST, [TEMPORARY_OPTIONS], CALLBACK )

Issue a POST request. POST value can be either a scalar, in which case it will
be sent literally, a HASHREF - will be uri-encoded, or a L<Net::Curl::Form>
object (L<Net::Curl::Simple::Form> is OK as well).

 $curl->post( $uri,
     { username => "foo", password => "bar" },
     \&finished
 );

=item put( URI, PUTDATA, [TEMPORARY_OPTIONS], CALLBACK )

Issue a PUT request. PUTDATA value can be either a file name, in which case the
file contents will be uploaded, a SCALARREF -- refered data will be uploaded,
or a CODEREF -- sub will be called like a C<CURLOPT_READFUNCTION> from
L<Net::Curl::Easy>, you should specify "infilesize" option in the last
case.

 $curl1->put( $uri, "filename", \&finished );
 $curl2->put( $uri, \"some data", \&finished );
 $curl3->put( $uri, sub {
         my ( $curl, $maxsize, $uservar ) = @_;
         read STDIN, my ( $r ), $maxsize;
         return \$r;
     },
     infilesize => EXPECTED_SIZE,
     \&finished
 );

=item code

Return result code. Zero means we're ok.

=item headers

Return a list of all headers. Equivalent to C<< @{ $curl->{headers} } >>.

=item content

Return transfer content. Equivalent to C<< $curl->{body} >>.

=item join

B<NOT IMPLEMENTED YET>

Wait for this download "thread" to finish.

=back

=head1 OPTIONS

Options can be either CURLOPT_* values (import them from Net::Curl::Easy),
or literal names, preferably in lower case, without the CURLOPT_ preffix.
For description of available options see L<curl_easy_setopt(3)>.

Names for getinfo can also be either CURLINFO_* values or literal names
without CURLINFO_ preffix.

=head1 SEE ALSO

L<Net::Curl::Simple::UserAgent>
L<Net::Curl::Simple::Async>
L<Net::Curl::Easy>

=head1 COPYRIGHT

Copyright (c) 2011 Przemyslaw Iskra <sparky at pld-linux.org>.

This program is free software; you can redistribute it and/or
modify it under the same terms as perl itself.

=cut

# vim: ts=4:sw=4
