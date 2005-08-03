# $Id: darwin.t,v 1.4 2005/08/03 21:22:48 Daddy Exp $

use ExtUtils::testlib;
use Test::More no_plan;
BEGIN { use_ok('Net::Address::Ethernet', qw( :all ), ) };

SKIP:
  {
  skip 'This is not darwin (MacOS)', 4 if ($^O !~ m!darwin!i);
  my $s = get_address;
  ok(defined($s));
  isnt($s, '');
  ok(is_address($s));
  is($s, canonical($s));
  diag(qq{FYI, your ethernet address is $s});
  my $sMethod = method;
  is($sMethod, 'ifconfig');
  my @a = get_address;
  diag(qq{in integer bytes, that's }. join(',', @a));
  is(scalar(@a), 6);
  } # end of SKIP block

__END__

