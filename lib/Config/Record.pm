# -*- perl -*-
#
# Config::Record by Daniel Berrange <dan@berrange.com>
#
# Copyright (C) 2000-2004 Daniel P. Berrange <dan@berrange.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# $Id: Record.pm,v 1.1 2004/02/10 19:03:50 dan Exp $

=pod

=head1 NAME

Config::Record - loading of configuration records

=head1 SYNOPSIS

  use Config::Record;

  my $config = Config::Record->new(filename => $filename,
                                   cache => $cache,
                                   locales => [ "en_EN", "en_US"],
                                   path => \@path,
                                   data => \%data);
  
  my $param = $config->param($key, [$default]);

=head1 DESCRIPTION

This module provides for loading and saving of simple configuration
file records. Entries in the configuration file are essentially
key,value pairs, with the key and values separated by a single equals
symbol. The C<key> consists only of alphanumeric characters. There are
three types of values, scalar values can contain anything except newlines.
Trailing whitespace will be trimmed unless the value is surrounded in
double quotes. eg

  foo = Wizz
  foo = "Wizz....    "

Array values  consist of a single right round bracket, following by
one C<value> per line, terminated by a single left round bracket. eg

  foo = (
    Wizz
    "Wizz...    "
  )

Hash values consist of a single right curly bracket, followed by one
key,value pair per line, terminated by a single left curly bracket.
eg

  foo = {
    one = Wizz
    two = "Wizz....  "
  }

Arrays and hashes can be nested to arbitrary depth.
While array entries can be optionally separated by commas,
howevere, this still does not allow more than one entry
per line. Likewise lines can be terminated by a redundant
semicolon if desired.


=head1 EXAMPLE

  name = Foo
  title = "Wizz bang wallop"
  eek = (
    OOhh
    Aahhh
    Wizz
  )
  people = (
    {
      forename = John
      surnamne = Doe
    }
    {
      forename = Some
      surname = One
    }
  )
  wizz = {
    foo = "Elk"
    ooh = "fds"
  }

=head1 METHODS

=over 4

=cut

package Config::Record;

use strict;
use Carp qw(confess);

use IO::File::Cached;
use File::Path::Localize;

use vars qw($VERSION $RELEASE);

$VERSION = "1.0.0";
$RELEASE = "1";

=pod

=item my $cache = Config::Record->new(filename => $filename, 
    [cache => $cache], [locale => $locale], [path => \@path]);

Creates a new config object, loading parameters from the file specified
by the C<filename> parameter. The C<cache> parameter optionally specifies
an instance of the C<Cache::Cache> interface to be used for caching the contents
of a file.

=cut

sub new
  {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = @_;

    my $filename = exists $params{filename} ? $params{filename} : confess "filename parameter is required";
    $self->{cache} = exists $params{cache} ? $params{cache} : undef;
    $self->{locales} = exists $params{locales} ? $params{locales} : undef;
    $self->{path} = exists $params{path} ? $params{path} : ['.'];

    bless $self, $class;
    
    $self->_parse($filename);
    
    return $self;
  }


sub _parse
  {
    my $self = shift;
    my $filename = shift;

    $self->{filename} = File::Path::Localize::locate(filename => $filename, 
        locales => $self->{locales}, path => $self->{path});

    confess "cannot find config file $filename" unless defined $self->{filename};

    my $data;
    {
      local $/ = undef;
      my $fh = IO::File::Cached->new(filename => $self->{filename},
				     cache => $self->{cache});
      $data = <$fh>;
      $fh->close;
    }
    
    my $value = {};
    my @stack = $value;
    my $line = 0;
    foreach (split /\n/, $data) {
      $line++;
      
      next if m|^\s*#|;
      next if m|^\s*$|;
      
      if (/^\s*((?:\w|-)+)\s*=\s*\(\s*$/) { # foo = (
        if (ref($value) eq "ARRAY") {
	  confess "unexpected key,value pair in $self->{filename} at line $line";
	}
      
        my $key = $1;
	
	my $new = [];
	$value->{$key} = $new;
	$value = $new;
	push @stack, $value;
      } elsif (/^\s*\(\s*$/) { # (
        if (ref($value) ne "ARRAY") {
	  confess "unexpected array entry in $self->{filename} at line $line";
	}
      
	my $new = [];
	push @{$value}, $new;
	$value = $new;
	push @stack, $value;
      } elsif (/^\s*\)\s*$/) { # )
        if (ref($value) ne "ARRAY") {
	  confess "mismatched closing round bracket in $self->{filename} at line $line";
	}
	if ($#stack == 0) {
	  confess "too many closing curley bracket in $self->{filename} at line $line";
	}
	
	pop @stack;
        $value = $stack[$#stack];
      } elsif (/^\s*((?:\w|-)+)\s*=\s*{\s*$/) { # foo = {
        if (ref($value) eq "ARRAY") {
	  confess "unexpected key,value pair in $self->{filename} at line $line";
	}
      
        my $key = $1;
	
	my $new = {};
	$value->{$key} = $new;
	$value = $new;
	push @stack, $value;
      } elsif (/^\s*{\s*$/) { # {
        if (ref($value) ne "ARRAY") {
	  confess "unexpected array entry in $self->{filename} at line $line";
	}
      
	my $new = {};
	push @{$value}, $new;
	$value = $new;
	push @stack, $value;
      } elsif (/^\s*}\s*$/) { # }
        if (ref($value) eq "ARRAY") {
	  confess "mismatched closing curly bracket in $self->{filename} at line $line";
	}
	if ($#stack == 0) {
	  confess "too many closing curley bracket in $self->{filename} at line $line";
	}
	
	pop @stack;
        $value = $stack[$#stack];
      } elsif (/^\s*((?:\w|-)+)\s*=\s*"(.*)"\s*$/ || # foo = "..."
               /^\s*((?:\w|-)+)\s*=\s*(.*?)\s*$/) { # foo = ...
        my $key = $1;
        my $val = $2;
	
	if (ref($value) eq "ARRAY") {
	  confess "expecting value, found key, value pair at line $line";
	}

	$value->{$key} = $val;
      } elsif (/^\s*"(.*)"\s*/ || # "..."
               /^\s*(.*?)\s*$/) { # ...
        my $val = $1;
	
	if (ref($value) ne "ARRAY") {
	  confess "expecting key,value pair, found value at line $line";
	}
	
	push @{$value}, $val;
      }
    }
    
    if ($#stack != 0) {
      confess "missing closing bracket in $self->{filename} at line $line";
    }
    
    $self->{params} = $stack[$#stack];
  }


sub param
  {
    my $self = shift;
    my $key = shift;
    
    my @key = split /\./, $key;
    
    my $entry = $self->{params};
    foreach (@key) {
      if (ref($entry) ne "HASH") {
        if (@_) {
          return shift;
	}
	confess "cannot find parameter $key";
      }
      
      if (!exists $entry->{$_}) {
        if (@_) {
          return shift;
	}
	confess "cannot find parameter $key";
      }
      
      $entry = $entry->{$_};
    }
    
    return $entry;
  }


1 # So that the require or use succeeds.

__END__

=back 4

=head1 AUTHORS

Daniel Berrange <dan@berrange.com>

=head1 COPYRIGHT

Copyright (C) 2000-2004 Daniel P. Berrange <dan@berrange.com>

=head1 SEE ALSO

L<perl(1)>

=cut
