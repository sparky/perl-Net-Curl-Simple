package WWW::CurlOO::Simple::Async::Perl;

use strict;
use warnings;
use WWW::CurlOO::Multi;
use base qw(WWW::CurlOO::Multi);

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
			$active = $ret;
			while ( my ( $msg, $easy, $result ) = $multi->info_read() ) {
				if ( $msg == WWW::CurlOO::Multi::CURLMSG_DONE ) {
					$multi->remove_handle( $easy );
					$easy->finish( $result );
				} else {
					die "I don't know what to do with message $msg.\n";
				}
			}
		}
	};

	return;
}

END {
	unless ( $loop_run ) {
		warn __PACKAGE__ . ": loop was never run\n";
		eval {
			WWW::CurlOO::Simple::Async::loop();
		};
	}
}

1;

# vim: ts=4:sw=4
