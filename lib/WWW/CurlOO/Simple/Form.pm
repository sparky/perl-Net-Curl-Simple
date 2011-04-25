package WWW::CurlOO::Simple::Form;

use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use WWW::CurlOO::Form;
use base qw(WWW::CurlOO::Form);

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

		# allow stacking
		return $form;
	}
}

sub add_contents
{
	my ( $form, $name, $contents ) = @_;
	$form->add( name => $name, contents => $contents );
}

sub add_file
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
 $form->add_contents( foo => "bar" )->add_file( photos => glob "*.jpg" );
 $form->add( name => "html", contents => "<html></html>",
     contenttype => "text/html" );

 $getter->post( $uri, \&finished, $form );

=head1 NOTHING HERE

Yeah, just a stub

=cut
# vim: ts=4:sw=4
