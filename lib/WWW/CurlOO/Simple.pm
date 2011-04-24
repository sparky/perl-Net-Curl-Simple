package WWW::CurlOO::Simple;

use strict;
use warnings;
use WWW::CurlOO::Easy;
use base qw(WWW::CurlOO::Easy);

our $VERSION = '0.01';

1;

=head1 NAME

WWW::CurlOO::Simple - simplify WWW::CurlOO::Easy interface

=head1 SYNOPSIS

 use WWW::CurlOO::Simple;

 my $getter = WWW::CurlOO::Simple->new();
 $getter->get( $uri, \&finished );

 sub finished
 {
     my ( $curl, $result ) = @_;
     print "document body: $curl->{body}\n";
 }

=head1 NOTHING HERE

Yeah, just a stub
