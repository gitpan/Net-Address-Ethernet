
# $Id: Makefile.PL,v 1.9 2008/02/25 03:35:34 Daddy Exp $

use inc::Module::Install;

name('Net-Address-Ethernet');
version_from('lib/Net/Address/Ethernet.pm');

author('Martin Thurn <mthurn@cpan.org>');
license('perl');

requires( perl => 5.004 );
recommends('Data::Dumper');
requires('Net::Domain');
requires('Net::Ifconfig::Wrapper');
requires('Regexp::Common');
requires('Sys::Hostname');
build_requires('Test::More');
build_recommends('Test::Pod');
build_recommends('Test::Pod::Coverage');

WriteAll();

__END__

