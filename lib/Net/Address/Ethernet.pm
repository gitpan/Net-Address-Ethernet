
# $Id: Ethernet.pm,v 1.98 2007/11/06 23:50:34 Daddy Exp $

=head1 NAME

Net::Address::Ethernet - find hardware ethernet address

=head1 SYNOPSIS

  use Net::Address::Ethernet qw( get_address );
  my $sAddress = get_address;
  my $sMethod = &Net::Address::Ethernet::method;

=head1 PLATFORM NOTES

On Windows (MSWin32), before calling this function, you can set
package variable $sIpconfigHome to the folder containing ipconfig.exe
(for example, if ipconfig.exe is not found your PATH, or if you don't
have permission to execute ipconfig.exe in the normal Windows
location).

  $Net::Address::Ethernet::sIpconfigHome = 'C:\\my\\bin';
  my $sAddr = &Net::Address::Ethernet::get_address;

=head1 FUNCTIONS

The following functions will be exported to your namespace if you request :all like so:

  use Net::Address::Ethernet qw( :all );

=over

=cut

package Net::Address::Ethernet;

use Carp;
use Data::Dumper; # for debugging only
use Exporter;
use Env::Path;
use File::Spec::Functions;
use Net::Domain;
use Regexp::Common;
use Sys::Hostname;

use strict;

my $DEBUG_MATCH = 0 || $ENV{N_A_E_DEBUG};
my $DEBUG_IPCONFIG = 0 || $ENV{N_A_E_DEBUG};

use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS );
@ISA = qw( Exporter );
$VERSION = do { my @r = (q$Revision: 1.98 $ =~ /\d+/g); sprintf "%d."."%03d" x $#r, @r };

%EXPORT_TAGS = ( 'all' => [ qw( get_address get_addresses method canonical is_address ), ], );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT = qw( );

my $sIpconfigHome = '';
my $sMethod = 'N/A';

my @ahInfo;

my $qrIPADDRESS = qr{\b(
                        IP\sAddress   # English
                        |
                        IP-Adresse    # German
                        |
                        Adresse\sIP   # French
                        )\b}ix;

sub _parse_ipconfig_output
  {
  my $ras = shift;
  # Clear out and start over:
  @ahInfo = ();
  my $sAdapterName = '';
  my $sEthernet = '';
  my $sIP = '';
  my $iActive = 0;
  foreach my $sLine (@$ras)
    {
    # Delete trailing whitespace:
    $sLine =~ s!\s+\Z!!;
    if ($sLine =~ m!\A(\S.+):\Z!)
      {
      $sAdapterName = $1;
      # Reset the other items:
      $sEthernet = $sIP = '';
      } # if
    elsif ($sLine =~ m!\s\.\s?:\s($RE{net}{MAC}{hex}{-sep=>qr/-/})\b!)
      {
      # Matched the 6-byte ethernet address:
      $sEthernet = $1;
      }
    elsif (($sLine =~ m!$qrIPADDRESS!)
           &&
           ($sLine =~ m!\.\s?:\s($RE{net}{IPv4})!i))
      {
      $sIP = $1;
      $iActive = ($sIP ne q/0.0.0.0/);
      push @ahInfo, {
                     sAdapter => $sAdapterName,
                     sEthernet => &canonical($sEthernet),
                     sIP => $sIP,
                     iActive => $iActive,
                    };
      $sMethod = 'ipconfig';
      } # elsif
    } # foreach
  # print STDERR Dumper(\@ahInfo);
  } # _parse_ipconfig_output


=item get_address

Returns the 6-byte ethernet address in canonical form.
For example, '1A:2B:3C:4D:5E:6F'.

When called in array context, returns a 6-element list representing
the 6 bytes of the address in decimal.  For example,
(26,43,60,77,94,111).

=cut

sub get_address
  {
  my @a = &get_addresses;
  $DEBUG_MATCH && print STDERR " DDD in get_address, a is ", Dumper(\@a);
  # Even if none are active, we'll return the first one:
  my $sAddr = $a[0]->{sEthernet};
  # Look through the list, returning the first active one:
 TRY_ADDR:
  foreach my $rh (@a)
    {
    if ($rh->{iActive})
      {
      next TRY_ADDR if ($rh->{sIP} eq '127.0.0.1');
      $sAddr = $rh->{sEthernet};
      last TRY_ADDR;
      } # if
    } # foreach TRY_ADDR
  return wantarray ? map { hex } split(/[-:]/, $sAddr) : &canonical($sAddr);
  } # get_addresses


=item get_addresses

Returns an array of hashrefs.
Each hashref describes one Ethernet adapter found in the current hardware configuration,
with the following entries filled in to the best of our ability to determine:

=over

=item sEthernet -- The MAC address in canonical form.

=item sIP -- The IP address on this adapter.

=item sAdapter -- The name of this adapter.

=item iActive -- Whether this adapter is active.

=back

For example:

  {
   'sAdapter' => 'Ethernet adapter Local Area Connection',
   'sEthernet' => '12:34:56:78:9A:BC',
   'sIP' => '111.222.33.44',
   'iActive' => 1,
  },


=cut

sub get_addresses
  {
  my $sAddr = undef;
  $sMethod = 'failed';
  my @asCmd;
  if ($^O =~ m!Win32!i)
    {
    my @asAddr;
    # Find out where ipconfig is:
    my $sIpconfig;
 TRY_IPCONFIG:
    foreach my $sTryDir ($sIpconfigHome,
                         Env::Path->PATH->List, curdir,
                         'C:\\windows\\system32', 'C:\\winnt\\system32')
      {
      $sIpconfig = catfile($sTryDir, 'ipconfig.exe');
      if (-x $sIpconfig)
        {
        last TRY_IPCONFIG;
        } # if
      undef $sIpconfig;
      } # foreach TRY_IPCONFIG
    goto ALL_DONE unless $sIpconfig;
    print STDERR " DDD found $sIpconfig\n" if $DEBUG_IPCONFIG;
    # Put double-quotes around it in case the path contains spaces:
    my @as = qx{ "$sIpconfig" /all };
    &_parse_ipconfig_output(\@as);
    } # if Win32
  elsif ($^O =~ m!linux!i)
    {
    $DEBUG_MATCH && print STDERR " DDD this is linux.\n";
    # I haven't seen any Linux where ifconfig does not give us all the
    # info we need, ergo skip arp:
    if (0)
      {
      my $ARP = q{/sbin/arp};
      if (-x $ARP)
        {
        my $re = qr{\sETHER\s+$RE{net}{MAC}{-keep}\s}i;
        my $sHostname = hostname || Net::Domain::hostname || '';
        my $sHostfqdn = Net::Domain::hostfqdn || '';
 LINUX_ARP_TRY:
        foreach my $sTry ($sHostname, $sHostfqdn)
          {
          next LINUX_ARP_TRY if ($sTry eq '');
          push @asCmd, qq{$ARP $sTry};
          } # foreach LINUX_ARP_TRY
        } # if
      else
        {
        # Can not find an executable arp
        # warn " WWW your OS is linux but you have no $ARP!?!\n";
        }
      } # if try arp
    my $IFCONFIG = q{/sbin/ifconfig};
    if (-x $IFCONFIG)
      {
      push @asCmd, qq{$IFCONFIG};
      } # if
    else
      {
      # Can not find an executable ifconfig
      # warn " WWW your OS is linux but you have no $IFCONFIG!?!\n";
      }
    } # if linux
  elsif ($^O =~ m!solaris!i)
    {
    my $ARP = q{/usr/sbin/arp};
    if (-x $ARP)
      {
      my $sHostname = hostname || Net::Domain::hostname || '';
      my $sHostfqdn = Net::Domain::hostfqdn || '';
 SOLARIS_ARP_TRY:
      foreach my $sTry ($sHostname, $sHostfqdn)
        {
        next SOLARIS_ARP_TRY if ($sTry eq '');
        push @asCmd, qq{$ARP $sTry};
        } # foreach SOLARIS_ARP_TRY
      } # if
    my $IFCONFIG = q{/usr/sbin/ifconfig};
    if (-x $IFCONFIG)
      {
      push @asCmd, qq{ $IFCONFIG -a };
      } # if
    else
      {
      # Can not find an executable ifconfig
      }
    } # if solaris
  elsif ($^O =~ m!darwin!i)
    {
    # Assume it's in the path:
    push @asCmd, qq{ ifconfig };
    } # if MACINTOSH
  elsif ($^O =~ m!cygwin!i)
    {
    # Assume it's in the path:
    push @asCmd, qq{ ipconfig };
    } # if MACINTOSH
  else
    {
    # Unknown operating system
    }
 CMD_TRY:
  foreach my $sCmd (@asCmd)
    {
    &_cmd_output_matches(\@ahInfo, $sCmd);
    } # foreach CMD_TRY
  $DEBUG_MATCH && print STDERR Dumper(\@ahInfo);
 ALL_DONE:
  return @ahInfo;
  } # get_addresses


my %hssMACofIP;

sub _cmd_output_matches
  {
  # Required arg1 = reference to array of results info:
  my $raInfo = shift;
  # Required arg2 = command-line to run:
  my $sCmd = shift;
  return if @ahInfo;
  $DEBUG_MATCH && print STDERR " DDD running cmd ==$sCmd==...\n";
  my @as = qx{ $sCmd };
  chomp @as;
 LINE_OF_CMD:
  while (@as)
    {
    my $sLine = shift @as;
    $DEBUG_MATCH && print STDERR " DDD output line of cmd ==$sLine==\n";
    if ($sLine =~ m!\(($RE{net}{IPv4})\)\s+AT\s+($RE{net}{MAC})\b!i)
      {
      # Looks like arp on Solaris.  Remember this IP => MAC for later...
      $hssMACofIP{$1} = $2;
      $DEBUG_MATCH && print STDERR " DDD   looks like arp on Solaris ($1=>$2)...\n";
      $sMethod = 'arp';
      } # if
    elsif ($sLine =~ m!\A(.+?):\s+flags=!)
      {
      # Looks like ifconfig on Solaris.  Remember this adapter name for later...
      my $sAdapter = $1;
      $DEBUG_MATCH && print STDERR " DDD   looks like ifconfig line 1 on Solaris ($sAdapter)...\n";
      # Look ahead to the IPv4 on the next line:
      $sLine = shift @as;
      if ($sLine =~ m!\bINET\s+($RE{net}{IPv4})\s+NETMASK!i)
        {
        my $sIP = $1;
        $DEBUG_MATCH && print STDERR " DDD   looks like ifconfig line 2 on Solaris (ip=$sIP)...\n";
        # Look ahead and see if "ether" appears on the next line (as darwin):
        $sLine = shift @as || '';
        if ($sLine =~ m!ETHER\s+($RE{net}{MAC})\b!i)
          {
          my $sMAC = $1;
          $DEBUG_MATCH && print STDERR " DDD   looks like ifconfig line 3 on darwin (ether=$sMAC)...\n";
          $hssMACofIP{$sIP} = $sMAC;
          } # if
        else
          {
          # Put the line back, in case this is not darwin:
          unshift @as, $sLine;
          }
        my $sEther = &canonical($hssMACofIP{$sIP} || '');
        $DEBUG_MATCH && print STDERR " DDD returning $sAdapter-->$sEther ($sIP)\n";
        push @ahInfo, {
                       sAdapter => $sAdapter,
                       sEthernet => $sEther,
                       sIP => $sIP,
                       # ifconfig only reports active addresses?
                       iActive => 1,
                      };
	$sMethod = 'ifconfig';
        } # if
      } # elsif
    elsif ($sLine =~ m!\A(.+?)\s.+\sHWADDR\s($RE{net}{MAC})!i)
      {
      # Looks like ifconfig on Fedora Core.  Remember this adapter
      # name for later...
      my $sAdapter = $1;
      my $sMAC = $2;
      $DEBUG_MATCH && print STDERR " DDD   looks like ifconfig line 1 on FC6 ($sAdapter,$sMAC)...\n";
      # Look ahead to the IPv4 on the next line:
      $sLine = shift @as;
      if ($sLine =~ m!\sINET\sADDR:($RE{net}{IPv4})\s!i)
        {
        my $sIP = $1;
        $DEBUG_MATCH && print STDERR " DDD   looks like ifconfig line 2 on FC6 (ip=$sIP)...\n";
        push @ahInfo, {
                       sAdapter => $sAdapter,
                       sEthernet => &canonical($sMAC),
                       sIP => $sIP,
                       # ifconfig only reports active addresses?
                       iActive => 1,
                      };
	$sMethod = 'ifconfig';
        } # if
      } # elsif
    } # while LINE_OF_CMD
  } # _cmd_output_matches


=item method

After a successful call to get_address(), the method() function will
tell you how the information was derived.  Currently there are three
possibilities: 'arp' or 'ifconfig' for Unix-like systems, and
'ipconfig' for Win32.  If you haven't called get_address(), 'N/A' will
be returned.  If something went wrong during get_address(), 'failed'
will be returned by method().

=cut

sub method
  {
  return $sMethod;
  } # method


=item is_address

Returns a true value if its argument looks like an ethernet address.

=cut

sub is_address
  {
  my $s = uc(shift || '');
  # Convert all non-hex digits to colon:
  $s =~ s![^0-9A-F]+!:!g;
  return ($s =~ m!\A$RE{net}{MAC}\Z!i);
  } # is_address


=item canonical

Given a 6-byte ethernet address, converts it to canonical form.
Canonical form is 2-digit uppercase hexadecimal numbers with colon
between the bytes.  The address to be converted can have any kind of
punctuation between the bytes, the bytes can be 1-digit, and the bytes
can be lowercase; but the bytes must already be hex.

=cut

sub canonical
  {
  my $s = shift;
  return '' if ! &is_address($s);
  # Convert all non-hex digits to colon:
  $s =~ s![^0-9a-fA-F]+!:!g;
  my @as = split(':', $s);
  # Cobble together 2-digit hex bytes:
  $s = '';
  map { $s .= length() < 2 ? "0$_" : $_; $s .= ':' } @as;
  chop $s;
  return uc $s;
  } # canonical

=back

=head1 NOTES

=head1 SEE ALSO

arp, ifconfig, ipconfig

=head1 BUGS

Please tell the author if you find any!  And please show me the output
of `ipconfig /all`
or `arp <hostname>`
or `ifconfig`
or `ifconfig -a`
from your system.

=head1 AUTHOR

Martin Thurn (mthurn@cpan.org).  L<http://www.sandcrawler.com/SWB/cpan-modules.html>

=cut

1;

__END__

This is an example of @asInfo on MSWin32:
(
   {
    'sAdapter' => 'Ethernet adapter Local Area Connection',
    'sEthernet' => '00-0C-F1-EE-F0-39',
    'sIP' => '16.25.10.14',
    'iActive' => 1,
   },
   {
    'sAdapter' => 'Ethernet adapter Wireless Network Connection',
    'sEthernet' => '00-33-BD-F3-33-E3',
    'sIP' => '19.16.20.12',
    'iActive' => 1,
   },
   {
    'sAdapter' => 'PPP adapter Verizon Online',
    'sEthernet' => '00-53-45-00-00-00',
    'sIP' => '71.24.23.85',
    'iActive' => 1,
   },
)

> /usr/sbin/arp myhost
myhost (14.81.16.10) at 03:33:ba:46:f2:ef permanent published

> /usr/sbin/ifconfig -a
lo0: flags=1000849<UP,LOOPBACK,RUNNING,MULTICAST,IPv4> mtu 8232 index 1
        inet 127.0.0.1 netmask ff000000
bge0: flags=1000843<UP,BROADCAST,RUNNING,MULTICAST,IPv4> mtu 1500 index 2
        inet 14.81.16.10 netmask ffffff00 broadcast 14.81.16.255
