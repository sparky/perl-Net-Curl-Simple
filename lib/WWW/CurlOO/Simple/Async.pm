package WWW::CurlOO::Simple::Async;

use strict;
use warnings;
use WWW::CurlOO;

our $VERSION = '0.01';

unless ( WWW::CurlOO::version_info()->{features}
		& WWW::CurlOO::CURL_VERSION_ASYNCHDNS ) {
	warn "Please rebuild libcurl with AsynchDNS to avoid"
		. " blocking DNS requests\n";
}

my @backends = (
	AnyEvent => 'AnyEvent',
	# POE => 'POE::Kernel',
	# IO_Async => 'IO::Async::Loop',
	# EV => 'EV',
	# Glib => 'Glib',
	Irssi => 'Irssi',
	Perl => undef, # direct approach
);

my $make_multi;
$make_multi = sub
{
	$make_multi = undef;

	my $multi;
	no strict 'refs';
	while ( my ( $impl, $pkg ) = splice @backends, 0, 2 ) {
		if ( not defined $pkg or defined ${ $pkg . '::VERSION' } ) {
			my $implpkg = join '::', __PACKAGE__, $impl;
			eval "require $implpkg";
			die $@ if $@;
			eval {
				$multi = $implpkg->new();
			};
			last if $multi;
		}
	}
	@backends = ();
	die "Could not load " . __PACKAGE__ . " implementation\n"
		unless $multi;

	return $multi;
};

sub import
{
	my $class = shift;
	my $impl = shift;
	return if not $impl or not $make_multi;
	# force some implementation
	@backends = ( $impl, undef );
}

my $multi;
sub add
{
	my $easy = shift;

	die "easy cannot _finish()\n"
		unless $easy->can( '_finish' );

	$multi = $make_multi->() unless $multi;
	$multi->add_handle( $easy );
}

sub loop
{
	return unless $multi;
	$multi->loop();
}

1;

=head1 NAME

WWW::CurlOO::Simple::Async - perform WWW::CurlOO requests asynchronously

=head1 SYNOPSIS

 use WWW::CurlOO::Simple;
 use WWW::CurlOO::Simple::Async;

 # this does not block now
 WWW::CurlOO::Simple->new()->get( $uri, \&finished );
 WWW::CurlOO::Simple->new()->get( $uri2, \&finished );

 # block until all requests are finished
 WWW::CurlOO::Simple::Async::loop();

 sub finished
 {
     my ( $curl, $result ) = @_;
     print "document body: $curl->{body}\n";
 }

=head1 NOTHING HERE

Yeah, just a stub
