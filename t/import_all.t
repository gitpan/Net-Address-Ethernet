
use ExtUtils::testlib;
use Test::More no_plan;
BEGIN { use_ok('Net::Address::Ethernet', qw( :all ), ) };

# Make sure the get_address() function was imported:
eval { my $s = get_address };
is($@, '');
# Make sure the method() function was imported:
eval { my $s = method };
is($@, '');
