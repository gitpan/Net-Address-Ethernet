
# $Id: Ethernet.pm,v 1.69 2005/08/03 21:18:42 Daddy Exp $

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

use Exporter;
use Regexp::Common;
use Sys::Hostname;

use strict;

use constant DEBUG_LINUX => 1;
use constant DEBUG_SOLARIS => 1;
use constant DEBUG_IPCONFIG => 0;

use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS );
@ISA = qw( Exporter );
$VERSION = do { my @r = (q$Revision: 1.69 $ =~ /\d+/g); sprintf "%d."."%03d" x $#r, @r };

%EXPORT_TAGS = ( 'all' => [ qw( get_address method canonical is_address ), ], );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT = qw( );

my $sMethod = 'N/A';

=item get_address

Returns the 6-byte ethernet address in canonical form.
For example, '1A:2B:3C:4D:5E:6F'.

When called in array context, returns a 6-element list representing
the 6 bytes of the address in decimal.  For example,
(26,43,60,77,94,111).

=cut

sub get_address
  {
  my $sAddr;
  # Hex digit fragment of a qr{}:
  my $b = '[0-9a-fA-F]';
  $sMethod = 'failed';
  if ($^O =~ m!Win32!i)
    {
    my @asAddr;
    my @as = qx{ ipconfig /all };
 LINE_IPCONFIG:
    foreach my $sLine (@as)
      {
      $sLine =~ s!\s+\Z!!;
      if ($sLine =~ m{(
                       Physical\s+Address     # English
                      |
                       Physikalische\s+Adresse  # German
                      |
                       Adresse\s+physique   # French
                      )}ix)
        {
        # Found a Physical Address line.
        print STDERR " DDD found phys line ==$sLine==\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
        # print STDERR " DDD   re=$RE{net}{MAC}{hex}{-sep=>qr/-/}=\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
        if ($sLine =~ m!\s$RE{net}{MAC}{hex}{-keep}{-sep=>qr/-/}\b!)
          {
          # Matched the 6-byte ethernet address:
          # print STDERR " DDD   1=$1= 2=$2= 3=$3= 4=$4= 5=$5= 6=$6= 7=$7=\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
          $sAddr = $1;
          print STDERR " DDD   found addr ==$sAddr==\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
          push @asAddr, $sAddr;
          # Don't return it until we make sure this adapter is active!
          } # found the ethernet address
        else
          {
          print STDERR " DDD   but no addr!\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
          }
        } # found "Physical Address"
      elsif (
             # This adapter shows a real IP address:
             ($sLine =~ m{\s(
                          IP\s+ADDRESS   # English
                          |
                          IP-Adresse     # German
                          |
                          Adresse\s+IP   # French
                          )}ix)
             &&
             ($sLine =~ m!\s$RE{net}{IPv4}!i)
             &&
             # The IP address is non-zero:
             ($sLine !~ m!\s0.0.0.0!i)
            )
        {
        print STDERR " DDD found ip   line ==$sLine==\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
        if ($sAddr ne '')
          {
          # We've already seen the ethernet address; return it:
          $sMethod = 'ipconfig';
          last LINE_IPCONFIG;
          } # we've already seen the physical address
        print STDERR " DDD   but no physical address line yet.\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
        } # found a non-zero IP address
      else
        {
        print STDERR " DDD some other line ==$sLine==\n" if (DEBUG_IPCONFIG || $ENV{N_A_E_DEBUG});
        }
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
    if (-f $ARP)
      {
      my $sHostname = hostname;
      # print STDERR " + hostname ==$sHostname==\n";
      my @as = qx{ $ARP $sHostname };
 LINE_ARP_LINUX:
      foreach my $sLine (@as)
        {
        DEBUG_LINUX && print STDERR " + line of arp ==$sLine==\n";
        if ($sLine =~ m!\sETHER\s+$RE{net}{MAC}{-keep}\s!i)
          {
          $sAddr = $1;
          $sMethod = 'arp';
          goto ALL_DONE;
          } # if
        } # foreach
      } # if
    # If we get here, then arp FAILED.  Try ifconfig:
    my $IFCONFIG = q{/sbin/ifconfig};
    if (-f $IFCONFIG)
      {
      my @as = qx{ $IFCONFIG };
 LINE_IFCONFIG_LINUX:
      foreach my $sLine (@as)
        {
        DEBUG_LINUX && print STDERR " + line of ifconfig ==$sLine==\n";
        if ($sLine =~ m!\bETHERNET\s+HWADDR\s+$RE{net}{MAC}{-keep}\b!i)
          {
          $sAddr = $1;
          $sMethod = 'ifconfig';
          goto ALL_DONE;
          } # if
        } # foreach
      } # if
    }
  elsif ($^O =~ m!solaris!i)
    {
    my $ARP = q{/usr/sbin/arp};
    if (-f $ARP)
      {
      my $sHostname = hostname;
      # print STDERR " + hostname ==$sHostname==\n";
      my @as = qx{ $ARP $sHostname };
    LINE_ARP_SOLARIS:
      foreach my $sLine (@as)
        {
        DEBUG_SOLARIS && print STDERR " + line of arp ==$sLine==\n";
        if ($sLine =~ m!\sAT\s+$RE{net}{MAC}{-keep}\s!i)
          {
          $sAddr = $1;
          $sMethod = 'arp';
          goto ALL_DONE;
          } # if
        } # foreach
      } # if
    # If we get here, then arp FAILED.  Try ifconfig:
    my $IFCONFIG = q{/usr/sbin/ifconfig};
    if (-f $IFCONFIG)
      {
      my @as = qx{ $IFCONFIG -a };
    LINE_IFCONFIG_SOLARIS:
      foreach my $sLine (@as)
        {
        DEBUG_SOLARIS && print STDERR " + line of ifconfig ==$sLine==\n";
        if ($sLine =~ m!\bETHER\s+$RE{net}{MAC}{-keep}\b!i)
          {
          $sAddr = $1;
          $sMethod = 'ifconfig';
          goto ALL_DONE;
          } # if
        } # foreach
      } # if
    }
  elsif ($^O =~ m!darwin!i)
    {
    my @as = qx{ ifconfig };
 LINE_IFCONFIG_DARWIN:
    foreach my $sLine (@as)
      {
      if($sLine =~ m!\sETHER\s+$RE{net}{MAC}{-keep}\s!i)
        {
        $sAddr = $1;
        $sMethod = 'ifconfig';
        goto ALL_DONE;
        } # if
      } # foreach
    } # if MACINTOSH
  else
    {
    # Unknown operating system
    }
 ALL_DONE:
  return wantarray ? map { hex } split(/[-:]/, $sAddr) : &canonical($sAddr);
  } # get_address


=item method

After a successful call to get_address(), the method() function will
tell you how the information was derived.  Currently there are two
possibilities: 'arp' for Unix-like systems, or 'ipconfig' for Win32.
If you haven't called get_address(), 'N/A' will be returned.  If
something went wrong during get_address, 'failed' will be returned by
method().

=cut

sub method
  {
  return $sMethod;
  } # method


=item is_address

Returns a true value if its argument is an ethernet address.

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

ipconfig, arp

=head1 BUGS

Please tell the author if you find any!  And please show me the output
format of `ipconfig /all` or `arp` from your system.

=head1 AUTHOR

Martin Thurn (mthurn@cpan.org).

=cut

1;

__END__

