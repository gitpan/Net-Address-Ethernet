
use inc::Module::Install;

name('Net-Address-Ethernet');
version_from('Ethernet.pm');

author('Martin Thurn <mthurn@cpan.org>');
license('perl');

requires( perl => 5.004 );
requires('Sys::Hostname');

# Test::More is needed for `make test`:
include_deps('Test::More', 5.004);
build_requires('Test::More');

check_nmake();      # check and download nmake.exe for Win32
&Makefile->write;
