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
# $Id: Record.pm,v 1.3 2004/04/01 19:32:57 dan Exp $

package Config::Record;

use strict;
use Carp qw(confess);
use IO::Handle;

use vars qw($VERSION $RELEASE);

$VERSION = "1.0.1";
$RELEASE = "1";

sub new
  {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = @_;

    $self->{file} = exists $params{file} ? $params{file} : confess "file parameter is required";

    bless $self, $class;

    my $fh;
    if (ref($self->{file})) {
      if (!$self->{file}->isa("IO::Handle")) {
	  confess "file must be an instance of IO::Handle";
      }
      $fh = $self->{file};
    } else {
      $fh = IO::File->new($self->{file});
    }
      
    $/ = undef;
    $self->_parse(<$fh>);
    $fh->close;
    
    return $self;
  }


sub _parse
  {
    my $self = shift;
    my $data = shift;

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

