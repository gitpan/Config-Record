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
# $Id: Record.pm,v 1.5 2004/05/14 13:44:49 dan Exp $

package Config::Record;

use strict;
use Carp qw(confess cluck);
use IO::File;

use warnings::register;

use vars qw($VERSION);

$VERSION = "1.0.3";

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = @_;
    
    $self->{record} = {};
    
    bless $self, $class;
    
    if (defined $params{file}) {
	$self->load($params{file});
    }
    
    return $self;
}


sub load {
    my $self = shift;
    my $file = shift;
    
    my $fh;
    if (ref($file)) {
	if (!$file->isa("IO::Handle")) {
	    confess "file must be an instance of IO::Handle";
	}
	$fh = $file;
    } else {
	$fh = IO::File->new($file)
	    or confess "cannot read from $file: $!";
    }
    
    local $/ = undef;
    my $data = <$fh>;
    $self->_parse($data,  ref($file) ? "<unknown>" : $file);
    $fh->close 
	or confess "cannot close file: $!";
}


sub _parse {
    my $self = shift;
    my $data = shift;
    my $filename = shift;

    my $value = {};
    my @stack = $value;
    my $line = 0;
    foreach (split /\n/, $data) {
	$line++;

	next if m|^\s*#|;
	next if m|^\s*$|;
	
	if (/^\s*((?:\w|-)+)\s*=\s*\(\s*$/) { # foo = ( 
	    if (ref($value) eq "ARRAY") {
		confess "unexpected key,value pair in $filename at line $line";
	    }
	    
	    my $key = $1;
	    
	    my $new = [];
	    $value->{$key} = $new;
	    $value = $new;
	    push @stack, $value;
	} elsif (/^\s*\(\s*$/) { # (
	    if (ref($value) ne "ARRAY") {
		confess "unexpected array entry in $filename at line $line";
	    }
	    
	    my $new = [];
	    push @{$value}, $new;
	    $value = $new;
	    push @stack, $value;
	} elsif (/^\s*\)\s*$/) { # )
	    if (ref($value) ne "ARRAY") {
		confess "mismatched closing round bracket in $filename at line $line";
	    }
	    if ($#stack == 0) {
		confess "too many closing curley bracket in $filename at line $line";
	    }
	    
	    pop @stack;
	    $value = $stack[$#stack];
	} elsif (/^\s*((?:\w|-)+)\s*=\s*{\s*$/) { # foo = {
	    if (ref($value) eq "ARRAY") {
		confess "unexpected key,value pair in $filename at line $line";
	    }
	    
	    my $key = $1;
	    
	    my $new = {};
	    $value->{$key} = $new;
	    $value = $new;
	    push @stack, $value;
	} elsif (/^\s*{\s*$/) { # {
	    if (ref($value) ne "ARRAY") {
		confess "unexpected array entry in $filename at line $line";
	    }
	    
	    my $new = {};
	    push @{$value}, $new;
	    $value = $new;
	    push @stack, $value;
	} elsif (/^\s*}\s*$/) { # }
	    if (ref($value) eq "ARRAY") {
		confess "mismatched closing curly bracket in $filename at line $line";
	    }
	    if ($#stack == 0) {
		confess "too many closing curley bracket in $filename at line $line";
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
	confess "missing closing bracket in $filename at line $line";
    }
		 
    $self->{record} = $stack[$#stack];
}
    
sub save {
    my $self = shift;
    my $file = shift;
    
    my $fh;
    if (ref($file)) {
	if (!$file->isa("IO::Handle")) {
	    confess "file must be an instance of IO::Handle";
	}
	$fh = $file;
    } else {
	$fh = IO::File->new(">$file")
	    or confess "cannot write to $file: $!";
    }

    foreach my $key (keys %{$self->{record}}) {
	print $fh "$key = ";
	$self->_format($fh, $self->{record}->{$key}, "");
    }
    
    $fh->close();
}

sub _format {
    my $self = shift;
    my $fh = shift;
    my $value = shift;
    my $indent = shift;

    my $ref = ref($value);
    
    if ($ref) {
	if ($ref eq "HASH") {
	    $self->_format_hash($fh, $value, $indent);
	} elsif ($ref eq "ARRAY") {
	    $self->_format_array($fh, $value, $indent);
	} else {
	    confess "unhandled reference $ref. Configuration files" .
		"can only contain unblessed scalars, array or hash references";
	}
    } else {
	$self->_format_scalar($fh, $value, $indent);
    }
}

sub _format_hash {
    my $self = shift;
    my $fh = shift;
    my $record = shift;
    my $indent = shift;
    
    print $fh "{\n";
    foreach my $key (keys %{$record}) {
	print $fh "$indent  $key = ";
	$self->_format($fh, $record->{$key}, "$indent  ");
    }
    print $fh "$indent}\n";
}

sub _format_array {
    my $self = shift;
    my $fh = shift;
    my $list = shift;
    my $indent = shift;
    
    print $fh "(\n";
    foreach my $element (@{$list}) {
	print $fh "$indent  ";
	$self->_format($fh, $element, "$indent  ");
	
    }
    print $fh "$indent)\n";
}

sub _format_scalar {
    my $self = shift;
    my $fh = shift;
    my $value = shift;
    my $indent = shift;
    
    if ($value =~ /^\s+/ ||
	$value =~ /\s+$/) {
	print $fh "\"$value\"\n";
    } else {
	print $fh "$value\n";
    }
}

sub param {
    my $self = shift;
    
    if (warnings::enabled()) {
	cluck "use of deprecated 'param' method. use 'get' instead";
    }

    return $self->get(@_);
}

sub get {
    my $self = shift;
    my $key = shift;
    
    my @key = split /\./, $key;
    
    my $entry = $self->{record};
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


sub set {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    
    my @key = split /\./, $key;
    
    my $entry = $self->{record};
    foreach (my $i = 0 ; $i <= $#key ; $i++) {
	if (ref($entry) ne "HASH") {
	    confess "cannot find parameter $key";
	}

	if ($i == $#key) {
	    $entry->{$key[$i]} = $value;
	} else {
	    if (!exists $entry->{$key[$i]}) {
		confess "cannot find parameter $key";
	    }
	    $entry = $entry->{$key[$i]};
	}
    }
}


sub record {
    my $self = shift;
    
    return $self->{record};
}

1 # So that the require or use succeeds.

