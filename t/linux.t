
use ExtUtils::testlib;
use Test::More no_plan;
BEGIN { use_ok('Net::Address::Ethernet', qw( :all ), ) };

SKIP:
  {
  skip 'This is not linux', 4 if ($^O !~ m!linux!i);
  my $s = get_address;
  ok(defined($s));
  isnt($s, '');
  ok(is_address($s));
  is($s, canonical($s));
  diag(qq{FYI, your ethernet address is $s});
  my $sMethod = method;
  like($sMethod, qr{arp|ifconfig});
  my @a = get_address;
  diag(qq{in integer bytes, that's }. join(',', @a));
  is(scalar(@a), 6);
  } # end of SKIP block
