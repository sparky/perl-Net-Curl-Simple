package WWW::CurlOO::Simple::Async::AnyEvent;

use strict;
use warnings;
use AnyEvent;
use WWW::CurlOO::Multi qw(/^CURL_POLL_/ /^CURL_CSELECT_/);
use base qw(WWW::CurlOO::Multi);

BEGIN {
	if ( not WWW::CurlOO::Multi->can( 'CURLMOPT_TIMERFUNCTION' ) ) {
		die "WWW::CurlOO::Multi is missing timer callback,\n" .
			"rebuild WWW::CurlOO with libcurl 7.16.0 or newer\n";
	}
}

sub _new
{
	my $class = shift;

	my $multi = $class->SUPER::new();

	$multi->setopt( WWW::CurlOO::Multi::CURLMOPT_SOCKETFUNCTION,
		\&_cb_socket );
	$multi->setopt( WWW::CurlOO::Multi::CURLMOPT_TIMERFUNCTION,
		\&_cb_timer );

	$multi->{active} = -1;

	return $multi;
}


# socket callback: will be called by curl any time events on some
# socket must be updated
sub _cb_socket
{
	my ( $multi, $easy, $socket, $poll ) = @_;

	# Right now $socket belongs to that $easy, but it can be
	# shared with another easy handle if server supports persistent
	# connections.
	# This is why we register socket events inside multi object
	# and not $easy.

	# deregister old io events
	delete $multi->{ "r$socket" };
	delete $multi->{ "w$socket" };

	# AnyEvent does not support registering a socket for both
	# reading and writing. This is rarely used so there is no
	# harm in separating the events.

	# register read event
	if ( $poll == CURL_POLL_IN or $poll == CURL_POLL_INOUT ) {
		$multi->{ "r$socket" } = AE::io $socket, 0, sub {
			$multi->socket_action( $socket, CURL_CSELECT_IN );
		};
	}

	# register write event
	if ( $poll == CURL_POLL_OUT or $poll == CURL_POLL_INOUT ) {
		$multi->{ "w$socket" } = AE::io $socket, 1, sub {
			$multi->socket_action( $socket, CURL_CSELECT_OUT );
		};
	}

	return 1;
}


# timer callback: It triggers timeout update. Timeout value tells
# us how soon socket_action must be called if there were no actions
# on sockets. This will allow curl to trigger timeout events.
sub _cb_timer
{
	my ( $multi, $timeout_ms ) = @_;
	#warn "on_timer( $timeout_ms )\n";

	# deregister old timer
	delete $multi->{timer};

	my $cb = sub {
		$multi->socket_action(
			WWW::CurlOO::Multi::CURL_SOCKET_TIMEOUT
		);
	};

	if ( $timeout_ms < 0 ) {
		# Negative timeout means there is no timeout at all.
		# Normally happens if there are no handles anymore.
		#
		# However, curl_multi_timeout(3) says:
		#
		# Note: if libcurl returns a -1 timeout here, it just means
		# that libcurl currently has no stored timeout value. You
		# must not wait too long (more than a few seconds perhaps)
		# before you call curl_multi_perform() again.

		if ( $multi->handles ) {
			$multi->{timer} = AE::timer 10, 10, $cb;
		}
	} else {
		# This will trigger timeouts if there are any.
		$multi->{timer} = AE::timer $timeout_ms / 1000, 0, $cb;
	}

	return 1;
}

# add one handle and kickstart download
sub add_handle($$)
{
	my $multi = shift;
	my $easy = shift;

	die "easy cannot finish()\n"
		unless $easy->can( 'finish' );

	# Calling socket_action with default arguments will trigger
	# socket callback and register IO events.
	#
	# It _must_ be called _after_ add_handle(); AE will take care
	# of that.
	#
	# We are delaying the call because in some cases socket_action
	# may finish inmediatelly (i.e. there was some error or we used
	# persistent connections and server returned data right away)
	# and it could confuse our application -- it would appear to
	# have finished before it started.
	AE::timer 0, 0, sub {
		$multi->socket_action();
	};

	$multi->SUPER::add_handle( $easy );
}

# perform and call any callbacks that have finished
sub socket_action
{
	my $multi = shift;

	my $active = $multi->SUPER::socket_action( @_ );
	return if $multi->{active} == $active;

	$multi->{active} = $active;

	while ( my ( $msg, $easy, $result ) = $multi->info_read() ) {
		if ( $msg == WWW::CurlOO::Multi::CURLMSG_DONE ) {
			$multi->remove_handle( $easy );
			$easy->finish( $result );
		} else {
			die "I don't know what to do with message $msg.\n";
		}
	}
}

1;
