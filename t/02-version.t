#
#
use Test::More tests => 3;

use WWW::CurlOO::Simple;
use WWW::CurlOO::Simple::UserAgent;
use WWW::CurlOO::Simple::Async;

is(
	$WWW::CurlOO::Simple::VERSION,
	$WWW::CurlOO::Simple::UserAgent::VERSION,
	'versions match'
);
is(
	$WWW::CurlOO::Simple::VERSION,
	$WWW::CurlOO::Simple::Async::VERSION,
	'versions match'
);
is(
	$WWW::CurlOO::Simple::UserAgent::VERSION,
	$WWW::CurlOO::Simple::Async::VERSION,
	'versions match'
);
