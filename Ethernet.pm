
# $Id: Ethernet.pm,v 1.6 2004/01/23 02:23:01 Daddy Exp $

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

=item canonical

Given a 6-byte ethernet address, converts it to canonical form.
Canonical form is 2-digit uppercase hexadecimal numbers with colon
between the bytes.  The address to be converted can have any kind of
punctuation between the bytes, the bytes can be 1-digit, and the bytes
can be lowercase; but the bytes must already be hex.

=item get_address

Returns the 6-byte ethernet address in canonical form.
For example, '1A:2B:3C:4D:5E:6F'.

When called in array context, returns a 6-element list representing
the 6 bytes of the address in decimal.  For example,
(26,43,60,77,94,111).

=item is_address

Returns a true value if its argument is an ethernet address.

=item method

After a successful call to get_address(), the method() function will
tell you how the information was derived.  Currently there are two
possibilities: 'arp' for Unix-like systems, or 'ipconfig' for Win32.
If you haven't called get_address(), 'N/A' will be returned.  If
something went wrong during get_address, 'failed' will be returned by
method().

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

#####################################################################

package Net::Address::Ethernet;

use Exporter;
use Sys::Hostname;

use strict;

use constant DEBUG_LINUX => 0;

use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS );
@ISA = qw( Exporter );
$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/o);

%EXPORT_TAGS = ( 'all' => [ qw( get_address method canonical is_address ), ], );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT = qw( );

my $sMethod = 'N/A';

sub method
  {
  return $sMethod;
  } # method

sub get_address
  {
  my $sAddr;
  # Hex digit fragment of a qr{}:
  my $b = '[0-9a-fA-F]';
  $sMethod = 'failed';
  if ($^O =~ m!Win32!i)
    {
    my @as = qx{ ipconfig /all };
 LINE_IPCONFIG:
    foreach my $sLine (@as)
      {
      if ($sLine =~ m!Physical\s+Address!i)
        {
        # Found a Physical Address line.
        if ($sLine =~ m!((?:$b$b-){5}$b$b)!)
          {
          # Matched the 6-byte ethernet address:
          $sAddr = $1;
          # Don't return it until we make sure this adapter is active!
          } # found the ethernet address
        } # found "Physical Address"
      elsif (
             # This adapter shows a real IP address:
             ($sLine =~ m!\sIP\s+ADDRESS!i)
             &&
             ($sLine =~ m!\s\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}!i)
             &&
             # The IP address is non-zero:
             ($sLine !~ m!\s0.0.0.0!i)
            )
        {
        if ($sAddr ne '')
          {
          # We've already seen the ethernet address; return it:
          $sMethod = 'ipconfig';
          last LINE_IPCONFIG;
          } # we've already seen the physical address
        } # found a non-zero IP address
      } # foreach LINE_IPCONFIG
    } # if Win32
  elsif ($^O =~ m!linux!i)
    {
    my @as = qx{ /sbin/arp };
    # chomp @as;
 LINE_ARP_LINUX:
    foreach my $sLine (@as)
      {
      DEBUG_LINUX && print STDERR " + line of arp ==$sLine==\n";
      if ($sLine =~ m!\sETHER\s+((?:$b$b:){5}$b$b)\s!i)
        {
        $sMethod = 'arp';
        $sAddr = $1;
        last LINE_ARP_LINUX;
        } # if
      } # foreach
    # If we get here, then /sbin/arp FAILED.  Try ipconfig:
    @as = qx{ /sbin/ifconfig };
 LINE_IFCONFIG_LINUX:
    foreach my $sLine (@as)
      {
      DEBUG_LINUX && print STDERR " + line of ifconfig ==$sLine==\n";
      if ($sLine =~ m!\bETHERNET\s+HWADDR\s+((?:$b$b:){5}$b$b)\b!i)
        {
        $sMethod = 'ifconfig';
        $sAddr = $1;
        last LINE_IFCONFIG_LINUX;
        } # if
      } # foreach
    }
  elsif ($^O =~ m!solaris!i)
    {
    my $sHostname = hostname;
    # print STDERR " + hostname ==$sHostname==\n";
    my @as = qx{ /usr/sbin/arp $sHostname };
 LINE_ARP_SOLARIS:
    foreach my $sLine (@as)
      {
      # print STDERR " +   line ==$sLine";
      if ($sLine =~ m!\sAT\s+((?:$b$b?:){5}$b$b?)\s!i)
        {
        $sMethod = 'arp';
        $sAddr = $1;
        last LINE_ARP_SOLARIS;
        } # if
      } # foreach
    }
  else
    {
    # Unknown operating system
    }
  return wantarray ? map { hex } split(/[-:]/, $sAddr) : &canonical($sAddr);
  } # get_address

sub is_address
  {
  my $s = shift || '';
  # Convert all non-hex digits to colon:
  $s =~ s![^0-9a-fA-F]+!:!g;
  $s .= ':';
  return ($s =~ m!\A([0-9a-f]{1,2}:){6}\Z!i);
  } # is_address

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

1;

__END__
