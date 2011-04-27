package WWW::CurlOO::Simple::Form;

use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use WWW::CurlOO::Form;
use base qw(WWW::CurlOO::Form);

our $VERSION = '0.02';

{
	my %optcache;

	sub add
	{
		my $form = shift;

		my @args;
		while ( my ( $opt, $val ) = splice @_, 0, 2 ) {
			unless ( looks_like_number( $opt ) ) {
				# convert option name to option number
				unless ( exists $optcache{ $opt } ) {
					eval '$optcache{ $opt } = '
						. "WWW::CurlOO::Form::CURLFORM_COPY\U$opt";
					eval '$optcache{ $opt } = '
						. "WWW::CurlOO::Form::CURLFORM_\U$opt"
						if $@;
					die "unrecognized literal option: $opt\n"
						if $@;
				}
				$opt = $optcache{ $opt };
			}

			push @args, $opt, $val;
		}

		$form->SUPER::add( @args );

		# allow chaining
		return $form;
	}
}

sub contents
{
	my ( $form, $name, $contents ) = @_;
	$form->add( name => $name, contents => $contents );
}

sub file
{
	my $form = shift;
	$form->add( name => shift, map +( file => $_ ), @_ );
}

1;

=head1 NAME

WWW::CurlOO::Simple::Form - simplify WWW::CurlOO::Form a little

=head1 SYNOPSIS

 use WWW::CurlOO::Simple;
 use WWW::CurlOO::Simple::Form;

 my $form = WWW::CurlOO::Simple::Form->new();
 $form->contents( foo => "bar" )->file( photos => glob "*.jpg" );
 $form->add( name => "html", contents => "<html></html>",
     contenttype => "text/html" );

 WWW::CurlOO::Simple->new->post( $uri, \&finished, $form );

=head1 DESCRIPTION

C<WWW::CurlOO::Simple::Form> is a thin layer over L<WWW::CurlOO::Form>.
It simplifies common tasks, while providing access to full power of
L<WWW::CurlOO::Form> when its needed.

=head1 CONSTRUCTOR

=over

=item new

Creates an empty multipart/formdata object.

 my $form = WWW::CurlOO::Simple::Form->new;

=back

=head1 METHODS

=over

=item add( OPTIONS )

Adds a section to this form. Behaves in the same way as add() from
L<WWW::CurlOO::Form> but also accepts literal option names. Returns its own
object to allow chaining.

=item contents( NAME, CONTENTS )

Shortcut for add( name => NAME, contents => CONTENTS ).

=item file( NAME, FILE1, [FILE2, [...] ] )

Shortcut for add( name => NAME, file => FILE1, file => FILE2, ... ).

=back

=head1 SEE ALSO

L<WWW::CurlOO::Simple>
L<WWW::CurlOO::Form>
L<curl_formadd(3)>

=head1 COPYRIGHT

Copyright (c) 2011 Przemyslaw Iskra <sparky at pld-linux.org>.

This program is free software; you can redistribute it and/or
modify it under the same terms as perl itself.

=cut

# vim: ts=4:sw=4
