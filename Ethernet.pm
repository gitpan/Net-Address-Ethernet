
# $Id: Ethernet.pm,v 1.2 2003-11-26 07:12:14-05 kingpin Exp kingpin $

=head1 NAME

Net::Address::Ethernet - find hardware ethernet address

=head1 SYNOPSIS

  use Net::Address::Ethernet qw( get_address );
  my $sAddress = get_address;
  my $sMethod = &Net::Address::Ethernet::method;

=head1 DESCRIPTION

The following functions will be exported to your namespace if you request :all like so:

  use Net::Address::Ethernet qw( :all );

=over

=item get_address

Returns the 6-byte ethernet address in hexadecimal format with colon
between the bytes.  For example, '1a:2b:3c:4d:5e:6f'.  No other
reformatting is done, so the hex digits can be capital or lowercase;
and each hex byte could be one or two digits.  For example,
'0:3:A:2B:3C:4D'.

=item method

After a successful call to get_address(), method() will tell you how
the information was derived.  Currently there are two possibilities:
'arp' for Unix-like systems, or 'ipconfig' for Win32.

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

use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS );
@ISA = qw( Exporter );
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/o);

%EXPORT_TAGS = ( 'all' => [ qw( get_address method ), ], );
@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT = qw( );

my $sMethod = 'N/A';

sub method
  {
  return $sMethod;
  } # method

sub get_address
  {
  # Hex digit fragment of a qr{}:
  my $b = '[0-9a-fA-F]';
  if ($^O =~ m!Win32!i)
    {
    my $sAddr;
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
          # Make it conform to our output spec:
          $sAddr =~ tr!-!:!;
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
          return $sAddr;
          } # we've already seen the physical address
        } # found a non-zero IP address
      } # foreach LINE_IPCONFIG
    } # if Win32
  elsif ($^O =~ m!linux!i)
    {
    my @as = qx{ /sbin/arp };
    foreach my $sLine (@as)
      {
      if ($sLine =~ m!\sETHER\s+((?:$b$b:){5}$b$b)\s!i)
        {
        $sMethod = 'arp';
        return $1;
        }
      }
    }
  elsif ($^O =~ m!solaris!i)
    {
    my $sHostname = hostname;
    # print STDERR " + hostname ==$sHostname==\n";
    my @as = qx{ /usr/sbin/arp $sHostname };
    foreach my $sLine (@as)
      {
      # print STDERR " +   line ==$sLine";
      if ($sLine =~ m!\sAT\s+((?:$b$b?:){5}$b$b?)\s!i)
        {
        $sMethod = 'arp';
        return $1;
        }
      }
    }
  else
    {
    
    }
  $sMethod = 'failed';
  return undef;
  } # get_address

1;

__END__
