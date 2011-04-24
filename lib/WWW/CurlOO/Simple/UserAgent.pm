package WWW::CurlOO::Simple::UserAgent;

use strict;
use warnings;

1;

=head1 NAME

WWW::CurlOO::Simple::UserAgent - share some data between multiple WWW::CurlOO::Simple objects

=head1 SYNOPSIS

 use WWW::CurlOO::Simple::UserAgent;

 my $ua = WWW::CurlOO::Simple::UserAgent->new(
     user_agent => "My::Downloader",
     proxy => "socks5:localhost:9980",
 );
 # those two requests share cookies and options set before
 $ua->curl()->get( $uri, \&finished );
 $ua->curl()->get( $uri2, \&finished );

 sub finished
 {
     my ( $curl, $result ) = @_;
     print "document body: $curl->{body}\n";
 }

=head1 NOTHING HERE

Yeah, just a stub
