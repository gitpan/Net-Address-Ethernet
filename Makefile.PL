
use inc::Module::Install;

name('Net-Address-Ethernet');
version_from('lib/Net/Address/Ethernet.pm');

author('Martin Thurn <mthurn@cpan.org>');
license('perl');

requires( perl => 5.004 );
requires('Sys::Hostname');

# Test::More is needed for `make test`:
build_requires('Test::More');
build_requires('Test::Pod');

check_nmake();      # check and download nmake.exe for Win32
&Makefile->write;
