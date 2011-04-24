package WWW::CurlOO::Simple::Async;

use strict;
use warnings;

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
