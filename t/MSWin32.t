
use ExtUtils::testlib;
use Test::More no_plan;
BEGIN { use_ok('Net::Address::Ethernet', qw( :all ), ) };

is(method, 'N/A');

SKIP:
  {
  skip 'This is not Windows', 4 if ($^O !~ m!win32!i);
  my $s = get_address;
  ok(defined($s));
  isnt($s, '');
  ok(is_address($s));
  is($s, canonical($s));
  diag(qq{FYI, your ethernet address is $s});
  my $sMethod = method;
  is($sMethod, 'ipconfig');
  my @a = get_address;
  diag(qq{in integer bytes, that's }. join(',', @a));
  is(scalar(@a), 6);
  } # end of SKIP block
