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
# $Id: Record.pm,v 1.8 2004/10/10 22:40:29 dan Exp $

package Config::Record;

use strict;
use Carp qw(confess cluck);
use IO::File;

use warnings::register;

use vars qw($VERSION);

$VERSION = "1.0.5";

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = @_;
    
    $self->{record} = {};
    $self->{debug} = $params{debug};
    
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
    my $here;
    my $continuation;

    my $LABEL = '((?:\w|-)+)';
    my $TRAILING_WHITESPACE = '\s*(?:\#.*)?';
    my $lineno = 0;

    my @lines = split /\n/, $data;

    foreach my $line (@lines) {
	$lineno++;
	warn "$lineno: '$line' '$here' '$continuation'\n" if $self->{debug};
	next if $line =~ m|^\s*#|;
	next if $line =~ m|^\s*$|;

	if ($here) {
	    if ($line =~ /\s*${here}\s*$/) { # EOF
		warn "$lineno: End of here doc\n" if $self->{debug};
		$here = undef;
		$continuation = undef;
	    } else {                # ...
		warn "$lineno: Middle of here doc\n" if $self->{debug};
		${$continuation} .= $line . "\n";
	    }
	} elsif ($continuation) {
	    if ($line =~ /^\s*"(.*?)"\s*(\\)?\s*$/ || # "..."
		$line =~ /^\s*(.*?)\s*(\\)?\s*$/) {   #  ...
		warn "$lineno: Continuation\n" if $self->{debug};
		${$continuation} .= $1;
		$continuation = undef unless $2;
	    } else {
		warn "$lineno: unexpected input '$line'\n";
	    }
	} else {
	    if ($line =~ /^\s*$LABEL\s*=\s*\(${TRAILING_WHITESPACE}$/) { # foo = ( 
		warn "$lineno: Key with array\n" if $self->{debug};
		if (ref($value) eq "ARRAY") {
		    confess "unexpected key,value pair in $filename at line $lineno";
		}
		
		my $key = $1;
		
		my $new = [];
		$value->{$key} = $new;
		$value = $new;
		push @stack, $value;
	    } elsif ($line =~ /^\s*\(${TRAILING_WHITESPACE}$/) { # (
		warn "$lineno: Start of array\n" if $self->{debug};
		if (ref($value) ne "ARRAY") {
		    confess "unexpected array entry in $filename at line $lineno";
		}
		
		my $new = [];
		push @{$value}, $new;
		$value = $new;
		push @stack, $value;
	    } elsif ($line =~ /^\s*\)${TRAILING_WHITESPACE}$/) { # )
		warn "$lineno: End of array\n" if $self->{debug};
		if (ref($value) ne "ARRAY") {
		    confess "mismatched closing round bracket in $filename at line $lineno";
		}
		if ($#stack == 0) {
		    confess "too many closing curley bracket in $filename at line $lineno";
		}
		
		pop @stack;
		$value = $stack[$#stack];
	    } elsif ($line =~ /^\s*$LABEL\s*=\s*{${TRAILING_WHITESPACE}$/) { # foo = {
		warn "$lineno: Key with hash\n" if $self->{debug};
		if (ref($value) eq "ARRAY") {
		    confess "unexpected key,value pair in $filename at line $lineno";
		}
		
		my $key = $1;
		
		my $new = {};
		$value->{$key} = $new;
		$value = $new;
		push @stack, $value;
	    } elsif ($line =~ /^\s*{${TRAILING_WHITESPACE}$/) { # {
		warn "$lineno: Start of hash\n" if $self->{debug};
		if (ref($value) ne "ARRAY") {
		    confess "unexpected array entry in $filename at line $lineno";
		}
		
		my $new = {};
		push @{$value}, $new;
		$value = $new;
		push @stack, $value;
	    } elsif ($line =~ /^\s*}${TRAILING_WHITESPACE}$/) { # }
		warn "$lineno: End of hash\n" if $self->{debug};
		if (ref($value) eq "ARRAY") {
		    confess "mismatched closing curly bracket in $filename at line $lineno";
		}
		if ($#stack == 0) {
		    confess "too many closing curley bracket in $filename at line $lineno";
		}
		
		pop @stack;
		$value = $stack[$#stack];
	    } elsif ($line =~ /^\s*$LABEL\s*=\s*<<(\w+)\s*$/) { # foo = <<EOF
		warn "$lineno: Key with here doc\n" if $self->{debug};
		my $key = $1;
		my $val = "";
		
		$value->{$key} = $val;

		$here = $2;
		$continuation = \$value->{$key};
	    } elsif ($line =~ /^\s*$LABEL\s*=\s*"(.*)"\s*(\\)?${TRAILING_WHITESPACE}$/ || # foo = "..."
		     $line =~ /^\s*$LABEL\s*=\s*(.*?)(\\)?\s*$/) { # foo = ...
		warn "$lineno: Key with string\n" if $self->{debug};
		my $key = $1;
		my $val = $2;
		
		if (ref($value) eq "ARRAY") {
		    confess "expecting value, found key, value pair at line $lineno";
		}
		
		$value->{$key} = $val;
		warn "$lineno: Start continuation\n" if $3 && $self->{debug};
		$continuation = \$value->{$key} if $3;
	    } elsif ($line =~ /^\s*<<(\w+)\s*$/) { # <<EOF
		warn "$lineno: Start of here doc\n" if $self->{debug};
		my $val = "";
		
		if (ref($value) ne "ARRAY") {
		    confess "expecting key,value pair, found value at line $lineno";
		}

		push @{$value}, $val;
		
		$here = $1;
		$continuation = \$value->[$#{$value}];
	    } elsif ($line =~ /^\s*"(.*)"\s*(\\)?${TRAILING_WHITESPACE}$/ || # "..."
		     $line =~ /^\s*(.*?)(\\)?\s*$/) { # ...
		warn "$lineno: Value\n" if $self->{debug};
		my $val = $1;
		
		if (ref($value) ne "ARRAY") {
		    confess "expecting key,value pair, found value at line $lineno";
		}
		
		push @{$value}, $val;
		
		$continuation = \$value->[$#{$value}] if $2;
	    } else {
		warn "Unexpected value '$line'\n";
	    }
	}
    }		 
    if ($#stack != 0) {
	confess "missing closing bracket in $filename at line $lineno";
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
    
    if ($value =~ /\n/) {
	$value .= "\n" unless $value =~ /\n$/;
	print $fh "<<EOF\n";
	print $fh $value;
	print $fh "EOF\n";
    } elsif ($value =~ /^\s+/ ||
	     $value =~ /\s+$/) {
	# XXX split long lines with \
	# XXX escape embedded "
	print $fh "\"$value\"\n";
    } else {
	# XXX split long lines with \
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

