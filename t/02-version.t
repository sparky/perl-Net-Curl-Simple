#
#
use Test::More tests => 3;

use WWW::CurlOO::Simple;
use WWW::CurlOO::Simple::UserAgent;
use WWW::CurlOO::Simple::Async;
use WWW::CurlOO::Simple::Form;

is(
	$WWW::CurlOO::Simple::VERSION,
	$WWW::CurlOO::Simple::UserAgent::VERSION,
	'UA version matches'
);
is(
	$WWW::CurlOO::Simple::VERSION,
	$WWW::CurlOO::Simple::Async::VERSION,
	'Async version matches'
);
is(
	$WWW::CurlOO::Simple::VERSION,
	$WWW::CurlOO::Simple::Form::VERSION,
	'Form version matches'
);
