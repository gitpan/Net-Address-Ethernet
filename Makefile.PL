
# $Id: Makefile.PL,v 1.13 2013/03/26 22:56:57 martin Exp $

use inc::Module::Install;

all_from('lib/Net/Address/Ethernet.pm');

requires( perl => 5.004 );
recommends('Data::Dumper');
requires('Net::Domain');
requires('Net::Ifconfig::Wrapper');
requires('Regexp::Common');
requires('Sys::Hostname');
test_requires('Test::More');
recommends('Test::Pod');
recommends('Test::Pod::Coverage');

WriteAll();

__END__

