
use ExtUtils::testlib;
use Test::More no_plan;
BEGIN { use_ok('Net::Address::Ethernet', qw( :all ), ) };

SKIP:
  {
  skip 'This is not linux', 3 if ($^O !~ m!linux!i);
  my $s = get_address;
  ok(defined($s));
  # Hex digit fragment of a qr{}:
  my $b = '[0-9a-fA-F]';
  like($s, qr/($b$b:){5}$b$b/);
  diag(qq{FYI, your ethernet address is $s});
  my $sMethod = method;
  is($sMethod, 'arp');
  } # end of SKIP block
