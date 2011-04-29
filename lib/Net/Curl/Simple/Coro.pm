package Net::Curl::Simple::Coro;

use strict;
use warnings;
{
	package Net::Curl::Simple::Async::Select;
	use Coro::Select qw(select);
	use Net::Curl::Simple::Async::Select;
}

our $VERSION = '0.05';

sub _perform($)
{
	my $easy = shift;
	my $multi = $easy->{multi}
		||= Net::Curl::Simple::Async::Select->new();

	$multi->add_handle( $easy );
	$multi->loop();
	$easy;
}

1;

=head1 NAME

Net::Curl::Simple::Coro - Coro integration for blocking Net::Curl requests

=head1 SYNOPSIS

 use Coro;
 use Net::Curl::Simple;

 my $c = async {
     Net::Curl::Simple->new()->get( $uri, \&finished );
     # this will be executed after finishing request
     ...
 };

 Net::Curl::Simple->new()->get( $uri2, \&finished );

 # make sure we end all the threads before we finish
 $c->join;

 sub finished
 {
     my ( $curl, $result ) = @_;
     print "document body: $curl->{body}\n";
 }

=head1 DESCRIPTION

If you really need simultaneous blocking requests use L<Coro>. If you don't
need blocking requests use L<Net::Curl::Simple::Async> instead.

This module will be loaded automatically if L<Coro> is loaded already but
L<Net::Curl::Simple::Async> is not.

=head1 SEE ALSO

L<Coro>
L<Net::Curl::Simple::Async>

=head1 COPYRIGHT

Copyright (c) 2011 Przemyslaw Iskra <sparky at pld-linux.org>.

This program is free software; you can redistribute it and/or
modify it under the same terms as perl itself.

=cut

# vim: ts=4:sw=4
