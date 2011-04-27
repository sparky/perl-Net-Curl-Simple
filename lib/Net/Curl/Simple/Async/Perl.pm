package Net::Curl::Simple::Async::Perl;

use strict;
use warnings;
use Net::Curl::Multi;
use base qw(Net::Curl::Multi);

my $loop_run = 0;

sub loop($)
{
	my $multi = shift;
	$loop_run = 1;

	my $active = $multi->handles;

	while ( $active ) {
		my $t = $multi->timeout;
		if ( $t != 0 ) {
			$t = 10000 if $t < 0;
			my ( $r, $w, $e ) = $multi->fdset;

			select $r, $w, $e, $t / 1000;
		}

		my $ret = $multi->perform();
		if ( $active != $ret ) {
			while ( my ( $msg, $easy, $result ) = $multi->info_read() ) {
				if ( $msg == Net::Curl::Multi::CURLMSG_DONE ) {
					$multi->remove_handle( $easy );
					$easy->_finish( $result );
				} else {
					die "I don't know what to do with message $msg.\n";
				}
			}
			$active = $multi->handles;
		}
	};

	return;
}

1;

# vim: ts=4:sw=4
