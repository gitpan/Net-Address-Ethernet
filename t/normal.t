
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
ok(defined($s));
isnt($s, '');
if (! ok(is_address($s)))
  {
  # Repeat the test with debugging turned on.  (Luckily, the module
  # does not cache results!):
  $Net::Address::Ethernet::DEBUG_MATCH = $Net::Address::Ethernet::DEBUG_MATCH = 88;
  $Net::Address::Ethernet::DEBUG_IPCONFIG = $Net::Address::Ethernet::DEBUG_IPCONFIG = 88;
  $s = get_address;
  } # if
is($s, canonical($s));
diag(qq{FYI, your ethernet address is $s});
my $sMethod = method;
SKIP:
  {
  skip qq{OS $sOS not known}, 1 if (! exists $hsqrMethod{$sOS});
  like($sMethod, $hsqrMethod{$sOS});
  } # end of SKIP block
my @a = get_address;
diag(qq{in integer bytes, that's }. join(',', @a));
is(scalar(@a), 6);

__END__

