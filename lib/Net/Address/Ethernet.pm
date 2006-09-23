
# $Id: Ethernet.pm,v 1.81 2006/09/23 15:00:37 Daddy Exp $

=head1 NAME

Net::Address::Ethernet - find hardware ethernet address

=head1 SYNOPSIS

  use Net::Address::Ethernet qw( get_address );
  my $sAddress = get_address;
  my $sMethod = &Net::Address::Ethernet::method;

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

use constant DEBUG_LINUX => 0;
use constant DEBUG_SOLARIS => 0;
use constant DEBUG_IPCONFIG => 0;

use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS );
@ISA = qw( Exporter );
$VERSION = do { my @r = (q$Revision: 1.81 $ =~ /\d+/g); sprintf "%d."."%03d" x $#r, @r };

%EXPORT_TAGS = ( 'all' => [ qw( get_address method canonical is_address ), ], );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT = qw( );

my $sIpconfigHome = '';
my $sMethod = 'N/A';

=item get_address

Returns the 6-byte ethernet address in canonical form.
For example, '1A:2B:3C:4D:5E:6F'.

When called in array context, returns a 6-element list representing
the 6 bytes of the address in decimal.  For example,
(26,43,60,77,94,111).

On Windows (MSWin32), before calling this function, you can set
package variable $sIpconfigHome to the folder containing ipconfig.exe
(for example, if ipconfig.exe is not found your PATH, or if you don't
have permission to execute ipconfig.exe in the normal Windows
location).

  $Net::Address::Ethernet::sIpconfigHome = 'C:\\my\\bin';
  my $sAddr = &Net::Address::Ethernet::get_address;

=cut

sub get_address
  {
  my $sAddr = undef;
  $sMethod = 'failed';
  my $sHostname = hostname || Net::Domain::hostname || '';
  my $sHostfqdn = Net::Domain::hostfqdn || '';
  my @aasCmd;
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
    print STDERR " DDD found $sIpconfig\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
    # Put double-quotes around it in case the path contains spaces:
    my @as = qx{ "$sIpconfig" /all };
 LINE_IPCONFIG:
    foreach my $sLine (@as)
      {
      $sLine =~ s!\s+\Z!!;
      print STDERR " DDD line ==$sLine==\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
      # print STDERR " DDD   re=$RE{net}{MAC}{hex}{-sep=>qr/-/}=\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
      if ($sLine =~ m!\s\.\s:\s$RE{net}{MAC}{hex}{-keep}{-sep=>qr/-/}\b!)
        {
        # Matched the 6-byte ethernet address:
        # print STDERR " DDD   1=$1= 2=$2= 3=$3= 4=$4= 5=$5= 6=$6= 7=$7=\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
        $sAddr = $1;
        print STDERR " DDD   found addr ==$sAddr==\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
        push @asAddr, $sAddr;
        # Don't return it until we make sure this adapter is active!
        next LINE_IPCONFIG;
        } # found the ethernet address
      if (
          # ASSUME that the FIRST address line after the mac is the IP
          # address (and ASSUME that the subnet mask, etc. are on
          # LATER lines:
          1 ||
          ($sLine =~ m{\s(
                          IP\sAddress   # English
                          |
                          IP-Adresse    # German
                          |
                          Adresse\sIP   # French
                          )}ix)
         )
        {
        # print STDERR " DDD   found ip   line ==$sLine==\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
        if ($sLine =~ m!\s:\s($RE{net}{IPv4})!i)
          {
          print STDERR " DDD   matched ip pattern ==$sLine==\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
          if ($1 ne q/0.0.0.0/)
          # The IP address is non-zero:
            {
            print STDERR " DDD   found non-zero ip ==$1==\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
            if ($sAddr ne '')
              {
              # We've already seen the ethernet address; return it:
              $sMethod = 'ipconfig';
	      goto ALL_DONE;
              # Reset our flag in case there are more adapters listed:
              $sAddr = '';
              last LINE_IPCONFIG;
              } # we've already seen the physical address
            print STDERR " DDD   but no physical address line yet.\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
            } # found a non-zero IP address
          } # found an IP address
        next LINE_IPCONFIG;
        } # found "IP address"
      print STDERR " DDD some other line ==$sLine==\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
      } # foreach LINE_IPCONFIG
    # If we get here, then no adapters were active.
    if (scalar(@asAddr) == 1)
      {
      # There was only one MAC address found; return it even though it
      # is not active:
      $sAddr = shift @asAddr;
      $sMethod = 'ipconfig';
      } # if only one MAC found
    } # if Win32
  elsif ($^O =~ m!linux!i)
    {
    my $ARP = q{/sbin/arp};
    if (-x $ARP)
      {
      my $re = qr{\sETHER\s+$RE{net}{MAC}{-keep}\s}i;
 LINUX_ARP_TRY:
      foreach my $sTry ($sHostname, $sHostfqdn)
        {
        next LINUX_ARP_TRY if ($sTry eq '');
        push @aasCmd, [qq{$ARP $sTry}, $re, 'arp'];
        } # foreach LINUX_ARP_TRY
      } # if
    else
      {
      # Can not find an executable arp
      # warn " WWW your OS is linux but you have no $ARP!?!\n";
      }
    my $IFCONFIG = q{/sbin/ifconfig};
    if (-x $IFCONFIG)
      {
      my $re = qr{\bETHERNET\s+HWADDR\s+$RE{net}{MAC}{-keep}\b}i;
      push @aasCmd, [qq{$IFCONFIG}, $re, 'ifconfig'];
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
    if (-f $ARP)
      {
      my $re = qr{\sAT\s+$RE{net}{MAC}{-keep}\s}i;
 SOLARIS_ARP_TRY:
      foreach my $sTry ($sHostname, $sHostfqdn)
        {
        next LINUX_ARP_TRY if ($sTry eq '');
        push @aasCmd, [qq{$ARP $sTry}, $re, 'arp'];
        } # foreach LINUX_ARP_TRY
      } # if
    my $IFCONFIG = q{/usr/sbin/ifconfig};
    if (-x $IFCONFIG)
      {
      my $re = qr{\bETHER\s+$RE{net}{MAC}{-keep}\b}i;
      push @aasCmd, [qq{ $IFCONFIG -a }, $re, 'ifconfig'];
      } # if
    else
      {
      # Can not find an executable ifconfig
      }
    } # if solaris
  elsif ($^O =~ m!darwin!i)
    {
    # Assume it's in the path:
    my $re = qr{\sETHER\s+$RE{net}{MAC}{-keep}\s}i;
    push @aasCmd, [qq{ ifconfig }, $re, 'ifconfig'];
    } # if MACINTOSH
  else
    {
    # Unknown operating system
    goto ALL_DONE;
    }
 CMD_TRY:
    foreach my $ra (@aasCmd)
      {
      ($sAddr, $sMethod) = _cmd_output_matches(@$ra);
      goto ALL_DONE if $sAddr;
      } # foreach CMD_TRY
 ALL_DONE:
  return wantarray ? map { hex } split(/[-:]/, $sAddr) : &canonical($sAddr);
  } # get_address


sub _cmd_output_matches
  {
  my $sCmd = shift;
  my $re = shift;
  my $sName = shift;
  my @as = qx{ $sCmd };
 LINE_OF_CMD:
  foreach my $sLine (@as)
    {
    DEBUG_LINUX && print STDERR " + line of arp ==$sLine==\n";
    if ($sLine =~ m!$re!)
      {
      return ($1, $sName);
      } # if
    } # foreach LINE_OF_CMD
  return (undef, undef);
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
  # print STDERR " DDD   is_address($s)\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
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

