
use ExtUtils::testlib;
use Test::More no_plan;
BEGIN { use_ok('Net::Address::Ethernet', qw( :all ), ) };

SKIP:
  {
  skip 'This is not Solaris', 4 if ($^O !~ m!solaris!i);
  my $s = get_address;
  ok(defined($s));
  isnt($s, '');
  diag(qq{FYI, your ethernet address is $s});
  my $sMethod = method;
  is($sMethod, 'arp');
  my @a = get_address;
  diag(qq{in integer bytes, that's }. join(',', @a));
  is(scalar(@a), 6);
  } # end of SKIP block
