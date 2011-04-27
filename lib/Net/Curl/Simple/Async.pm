package Net::Curl::Simple::Async;

use strict;
use warnings;
use Net::Curl;

our $VERSION = '0.03';

unless ( Net::Curl::version_info()->{features}
		& Net::Curl::CURL_VERSION_ASYNCHDNS ) {
	warn "Please rebuild libcurl with AsynchDNS to avoid"
		. " blocking DNS requests\n";
}

my @backends = (
	Irssi => 'Irssi',
	AnyEvent => 'AnyEvent',
	# POE => 'POE::Kernel',
	# IO_Async => 'IO::Async::Loop',
	# EV => 'EV',
	# Glib => 'Glib',
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

Net::Curl::Simple::Async - perform Net::Curl requests asynchronously

=head1 SYNOPSIS

 use Net::Curl::Simple;
 use Net::Curl::Simple::Async;

 # this does not block now
 Net::Curl::Simple->new()->get( $uri, \&finished );
 Net::Curl::Simple->new()->get( $uri2, \&finished );

 # block until all requests are finished, may not be needed
 Net::Curl::Simple::Async::loop();

 sub finished
 {
     my ( $curl, $result ) = @_;
     print "document body: $curl->{body}\n";
 }

=head1 DESCRIPTION

If you use C<Net::Curl::Simple::Async> your L<Net::Curl::Simple> objects
will no longer block.

If your code is using L<Net::Curl::Simple> correctly (that is - processing
any finished requests in callbacks), the only change needed to add
asynchronous support is adding:

 use Net::Curl::Simple::Async;

It will pick up best Async backend automatically. However, you may force
some backend if you don't like the one detected:

 use Irssi;
 # Irssi backend would be picked
 use Net::Curl::Simple::Async qw(AnyEvent);

You may need to call loop() function if your code does not provide any
suitable looping mechanism.

=head1 FUNCTIONS

=over

=item loop

Block until all requests are complete. Some backends may not support it.
Most backends don't need it.

=back

=head1 BACKENDS

In order of preference (C<Net::Curl::Simple::Async> will try them it that
order):

=over

=item Irssi

Will be used if Irssi has been loaded. Does not support loop(), the function
will issue a warning and won't block.

=item AnyEvent

Will be used if AnyEvent has been loaded. In most cases you will already have
a looping mechanism on your own, but you can call loop() if you don't need
anything better.

=item Perl

Direct loop implementation in perl. Will be used if no other backend has been
found. You must call loop() to get anything done.

=back

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
