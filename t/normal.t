
use ExtUtils::testlib;
use Test::More 'tests' => 7;
BEGIN { use_ok('Net::Address::Ethernet', qw( :all ), ) };

my %hsqrMethod = (
                  'cygwin' => qr{\Aipconfig\z},
                  'darwin' => qr{\Aifconfig\z},
                  'linux' => qr{\A(arp|ifconfig)\z},
                  'MSWin32' => qr{\Aipconfig\z},
                  'solaris' => qr{\A(arp|ifconfig)\z},
                 );

my $sOS = $^O;
my $s = get_address;
ok(defined($s), 'defined');
isnt($s, '', 'not empty');
my $iIsAnAddress = ok(is_address($s), 'looks like an address');
if (0 && ! $iIsAnAddress)
  {
  # I'd like to repeat the test with debugging turned on, to see what
  # it's trying to parse.  (Unfortunately, the module caches its
  # parsed results!)
  $s = get_address(88);
  } # if
is($s, canonical($s), 'is canonical');
diag(qq{FYI, your ethernet address is $s});
my $sMethod = method;
SKIP:
  {
  skip qq{OS $sOS not known}, 1 if (! exists $hsqrMethod{$sOS});
  like($sMethod, $hsqrMethod{$sOS}, 'method');
  } # end of SKIP block
# Test for array context:
my @a = get_address(0);
diag(qq{in integer bytes, that's }. join(',', @a));
is(scalar(@a), 6, 'got 6 bytes');

__END__

