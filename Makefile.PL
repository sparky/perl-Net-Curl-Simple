use strict;
use ExtUtils::MakeMaker;

# older perl seems to choke on it, maybe utf8::upgrade would work ?
my $l_ = $] >= 5.010 ? "ł" : "l";
WriteMakefile(
	NAME 		=> 'Net::Curl::Simple',
	VERSION_FROM	=> 'lib/Net/Curl/Simple.pm',
	ABSTRACT_FROM	=> 'lib/Net/Curl/Simple.pm',
	AUTHOR		=> "Przemys${l_}aw Iskra <sparky at pld-linux.org>",
	META_MERGE	=> {
	},
	SIGN		=> 1,
	LICENSE		=> 'perl',
	CONFIGURE_REQUIRES => {
		"ExtUtils::MakeMaker" => 0,
	},
	PREREQ_PM => {
		# all tests require those
		"Net::Curl" => "0.17",
		"Test::More" => 0,
		"URI" => 0,
	},
	META_MERGE	=> {
		requires => {
			# some tests use those, but we don't want overzealous cpan
			# clients to install them
			"EV" => "4.00",
			"AnyEvent" => "5.00",
			"POE" => 0,
			"Coro" => 0,
		},
		resources => {
			repository => 'https://github.com/sparky/perl-Net-Curl-Simple'
		},
	},
	DIR			=> [], # no other Makefile.PL
);

sub MY::postamble
{
	return << 'EOM';
.PHONY: testall disttestall version_update
testall:
	TEST_AUTHOR=1 TEST_EXTENDED=1 $(MAKE) test

disttestall:
	TEST_AUTHOR=1 TEST_EXTENDED=1 $(MAKE) disttest

version_update:
	sed -i "/VERSION\s*=/s/=\s*'.*'/= '$(VERSION)'/" lib/Net/Curl/Simple/*.pm
EOM
}

# vim: ts=4:sw=4
