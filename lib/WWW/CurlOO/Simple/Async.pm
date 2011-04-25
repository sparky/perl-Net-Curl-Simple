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
sub _add
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

 # block until all requests are finished, may not be needed
 WWW::CurlOO::Simple::Async::loop();

 sub finished
 {
     my ( $curl, $result ) = @_;
     print "document body: $curl->{body}\n";
 }

=head1 DESCRIPTION

If your code is using L<WWW::CurlOO::Simple> correctly (that is - processing
any finished requests in callbacks), the only change needed to add
asynchronous support is adding:

 use WWW::CurlOO::Simple::Async;

It will pick up best Async backend automatically.

=head1 FUNCTIONS

=over

=item loop

Block until all requests are complete. Some backends may not support it.

=back

=head1 BACKENDS

In order of preference.

=over

=item AnyEvent

Will be used if AnyEvent has been loaded. There should be no need to use
loop() but it should work in most cases.

=item Irssi

Will be used if Irssi has been loaded. Does not support loop() - it will not
block.

=item Perl

Direct loop implementation in perl. Will be used if no other backend has been
found. You must call loop() to get anything done.

=back

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
