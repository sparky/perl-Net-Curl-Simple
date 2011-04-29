package Net::Curl::Simple::Async;

use strict;
use warnings;
use Net::Curl;

our $VERSION = '0.04';

use constant
	can_asynchdns => ( ( Net::Curl::version_info()->{features}
		& Net::Curl::CURL_VERSION_ASYNCHDNS ) != 0 );

sub warn_noasynchdns($) { warn @_ }


# load specified backend (left) if appropriate module (right)
# is loaded already
my @backends = (
	# backends we support directly
	EV => 'EV',
	Irssi => 'Irssi',
	POE => 'POE::Kernel',
	AnyEvent => 'AnyEvent',

	# AnyEvent supports some implementations we don't
	AnyEvent => 'AnyEvent::Impl::Perl',
	AnyEvent => 'Cocoa::EventLoop',
	AnyEvent => 'Event',
	AnyEvent => 'Event::Lib',
	AnyEvent => 'Glib',
	AnyEvent => 'IO::Async::Loop',
	AnyEvent => 'Qt',
	AnyEvent => 'Tk',

	# some POE::Loop::* implementations,
	# AnyEvent is preffered as it gives us a more
	# direct access to those backends
	POE => 'Event',
	POE => 'Event::Lib',
	POE => 'Glib',
	POE => 'Gtk', # not gtk2
	POE => 'Prima',
	POE => 'Tk',
	POE => 'Wx',

	# forced backends: try to load if nothing better detected
	EV => undef, # most efficient implementation
	AnyEvent => undef, # AnyEvent may have some nice alternative
	Perl => undef, # will work everywhere and much faster than POE
);


sub _get_multi()
{
	my $multi;

	no strict 'refs';
	while ( my ( $impl, $pkg ) = splice @backends, 0, 2 ) {
		if ( not defined $pkg or defined ${ $pkg . '::VERSION' } ) {
			my $implpkg = join '::', __PACKAGE__, $impl;
			eval "require $implpkg";
			next if $@;
			eval {
				$multi = $implpkg->new();
			};
			last if $multi;
		}
	}
	@backends = ();
	die "Could not load " . __PACKAGE__ . " implementation\n"
		unless $multi;

	warn_noasynchdns "Please rebuild libcurl with AsynchDNS to avoid"
		. " blocking DNS requests\n" unless can_asynchdns;

	no warnings 'redefine';
	*_get_multi = sub () { $multi };

	return $multi;
};

sub import
{
	my $class = shift;
	return if not @_;
	# force some implementation
	@backends = map +($_, undef), @_;
}

sub _add($)
{
	my $easy = shift;

	die "easy cannot _finish()\n"
		unless $easy->can( '_finish' );

	_get_multi->add_handle( $easy );
}

sub loop
{
	_get_multi->loop();
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
some backends if you don't like the one detected:

 use Irssi;
 # Irssi backend would be picked
 use Net::Curl::Simple::Async qw(AnyEvent POE);

You may need to call loop() function if your code does not provide any
suitable looping mechanism.

=head1 FUNCTIONS

=over

=item loop

Block until all requests are complete. Some backends may not support it.
Most backends don't need it.

=item can_asynchdns

Will tell you whether libcurl has AsyncDNS capability.

=item warn_noasynchdns

Function used to warn about lack of AsynchDNS. You can overwrite it if you
hate the warning.

 {
     no warnings;
     # don't warn at all
     *Net::Curl::Simple::Async::warn_noasynchdns = sub ($) { };
 }

Lack of AsynchDNS support in libcurl can severely reduce
C<Net::Curl::Simple::Async> efficiency. You should not disable the warning,
just replace it with a method more suitable in your application.

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
