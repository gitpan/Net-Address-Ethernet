
use ExtUtils::testlib;
use Test::More no_plan;
BEGIN { use_ok('Net::Address::Ethernet', qw( :all ), ) };

is(method, 'N/A');

SKIP:
  {
  skip 'This is not Windows', 4 if ($^O !~ m!win32!i);
  my $s = get_address;
  ok(defined($s));
  # Hex digit fragment of a qr{}:
  my $b = '[0-9a-fA-F]';
  like($s, qr/($b$b:){5}$b$b/);
  diag(qq{FYI, your ethernet address is $s});
  my $sMethod = method;
  is($sMethod, 'ipconfig');
  my @a = get_address;
  diag(qq{in integer bytes, that's }. join(',', @a));
  is(scalar(@a), 6);
  } # end of SKIP block
