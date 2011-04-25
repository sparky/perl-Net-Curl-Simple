package WWW::CurlOO::Simple::Async;

use strict;
use warnings;

my @backends = (
	AnyEvent => 'AnyEvent',
	# POE => 'POE::Kernel',
	# POE => 'Wx',
	# POE => 'Prima',
	# IO_Async => 'IO::Async::Loop',
	# EV => 'EV',
	# Glib => 'Glib',
	Irssi => 'Irssi',
	Perl => undef, # direct approach
);

my $multi;
sub _make_multi
{
	no strict 'refs';
	while ( my ( $impl, $pkg ) = splice @backends, 0, 2 ) {
		if ( not defined $pkg or defined ${ $pkg . '::VERSION' } ) {
			my $implpkg = join '::', __PACKAGE__, $impl;
			eval "require $implpkg";
			eval {
				$multi = $implpkg->new();
			};
			last if $multi;
		}
	}
	@backends = ();
	die "Could not load WWW::CurlOO::Simple::Async implementation\n"
		unless $multi;
}

sub add
{
	my $easy = shift;
	_make_multi() unless $multi;
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
