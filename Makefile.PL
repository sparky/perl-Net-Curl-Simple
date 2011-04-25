use strict;
use ExtUtils::MakeMaker;

# older perl seems to choke on it, maybe utf8::upgrade would work ?
my $l_ = $] >= 5.010 ? "ł" : "l";
WriteMakefile(
	NAME 		=> 'WWW::CurlOO::Simple',
	VERSION_FROM	=> 'lib/WWW/CurlOO/Simple.pm',
	ABSTRACT_FROM	=> 'lib/WWW/CurlOO/Simple.pm',
	AUTHOR		=> "Przemys${l_}aw Iskra <sparky at pld-linux.org>",
	META_MERGE	=> {
		resources => {
			repository => 'https://github.com/sparky/perl-WWW-CurlOO-Simple'
		},
	},
	SIGN		=> 1,
	LICENSE		=> 'perl',
	MIN_PERL_VERSION => 5.008001,
	CONFIGURE_REQUIRES => {
		"ExtUtils::MakeMaker" => 0,
	},
	PREREQ_PM => {
		"WWW::CurlOO" => "0.15",
		"Test::More" => 0,
	},
	DIR			=> [], # no other Makefile.PL
);

# vim: ts=4:sw=4
