# $Id: 005Config.t,v 1.4 2004/09/26 23:31:38 dan Exp $

use Test::More tests => 28;

BEGIN { use_ok("Config::Record") }

$| = undef;
use warnings;
use Carp qw(confess);
use Test::Harness;
use File::Temp qw(tempfile);
use IO::File;

no warnings 'Config::Record';

my $config = <<END;
  name = Foo
  title = "Wizz bang wallop"
  label = "First string " \\
          "split across"
  description = <<EOF
This is a multi-line paragraph.
This is the second line.
And the third
EOF
  eek = ( # Testing an array
    OOhh
    " Aahhh "
    Wizz \\
    Bang
    <<EOF
A long paragraph in
here
EOF
  )
  people = ( # Testing an array of hashes
    {
      forename = John
      surnamne = Doe
    }
    {
      forename = Some
      surname = One
    }
  )
  wizz = { # Testing a hash
    foo = "Elk"
    ooh = "fds"
  }
  wibble = { # Testing a hash of hashes
    nice = {
      ooh = (
        weee
        {
          aah = sfd
          oooh = "   Weeee   "
        }
      )
    }
  }
END

my ($fh, $file) = tempfile("tmpXXXXXXX", UNLINK => 1);
print $fh $config;
close $fh;

# First test the constructor with a filename
my $cfg = Config::Record->new(file => $file, debug => ($ENV{TEST_DEBUG} || 0));

# Test plain string
is($cfg->param("name"), "Foo", "Plain string");

# Test quoted string
is($cfg->param("title"), "Wizz bang wallop", "Quoted string");

# Test continuation
is($cfg->param("label"), "First string split across", "Continuation");

# Test here doc
is($cfg->param("description"), <<EOF
This is a multi-line paragraph.
This is the second line.
And the third
EOF
, "Here doc");

# Test array element continuation
is($cfg->param("eek")->[2], "Wizz Bang", "Continuation");

# Test array here doc
is($cfg->param("eek")->[3], "A long paragraph in\nhere\n", "Here doc");

# Test defaults
is($cfg->param("nada", "eek"), "eek", "Defaults");


# Now test the constructor with a file handle
$fh = IO::File->new($file);
$cfg = Config::Record->new(file => $fh);

# Test plain string
is($cfg->param("name"), "Foo", "Plain string");

# Test quoted string
is($cfg->param("title"), "Wizz bang wallop", "Quoted string");

# Test continuation
is($cfg->param("label"), "First string split across", "Continuation");

# Test here doc
is($cfg->param("description"), <<EOF
This is a multi-line paragraph.
This is the second line.
And the third
EOF
, "Here doc");

# Test array element continuation
is($cfg->param("eek")->[2], "Wizz Bang", "Continuation");

# Test array here doc
is($cfg->param("eek")->[3], "A long paragraph in\nhere\n", "Here doc");

# Test defaults
is($cfg->param("nada", "eek"), "eek", "Defaults");

# Test with empty constructor & load method

$cfg = Config::Record->new();

# Shouldn't be anything there yet
eval "$cfg->param('name')";
ok($@ ? 1 : 0, "No defaults");

# Lets set an option
$cfg->set("name" => "Blah");
is($cfg->param("name"), "Blah", "Set option");

# Now load the config record
$fh = IO::File->new($file);
$cfg->load($fh);

# Test plain string - should have overwritten 'Blah'
is($cfg->param("name"), "Foo", "Reload plain string");

# Test quoted string
is($cfg->param("title"), "Wizz bang wallop", "Reloaded quoted string");

# Test defaults
is($cfg->param("nada", "eek"), "eek", "Reloaded defaults");


# Now write it out to another file....
my ($fh2, $file2) = tempfile("tmpXXXXXXX", UNLINK => 1);
$fh2->close;
$cfg->save($file2);

# ...and then read it back in
my $cfg2 = Config::Record->new(file => $file2);

# Test plain string
is($cfg2->param("name"), "Foo", "Saved plain string");

# Test quoted string
is($cfg2->param("title"), "Wizz bang wallop", "Saved quoted string");

# Test continuation
is($cfg->param("label"), "First string split across", "Continuation");

# Test here doc
is($cfg->param("description"), <<EOF
This is a multi-line paragraph.
This is the second line.
And the third
EOF
, "Here doc");

# Test array element continuation
is($cfg->param("eek")->[2], "Wizz Bang", "Continuation");

# Test array here doc
is($cfg->param("eek")->[3], "A long paragraph in\nhere\n", "Here doc");

# Test defaults
is($cfg2->param("nada", "eek"), "eek", "Saved defaults");

# Now recursively compare entire hash
eq_hash($cfg->record, $cfg2->record, "Entire hash");

# Finally test the constructor with bogus ref

my $bogus = {};
bless $bogus, "Bogus";
eval "Config::Record->new(file => $bogus)";
ok($@ ? 1 : 0, "Bogus constructor");


exit 0;

sub compare {
  my $a = shift;
  my $b = shift;
  
  my $ar = ref($a);
  my $br = ref($b);
  
  if (defined $ar) {
    if (!defined $br) {
      return 0;
    }
    if ($ar ne $br) {
      return 0;
    }
    if ($ar eq "HASH") {
      foreach my $key (keys %{$a}) {
	if (!exists $b->{$key}) {
	  return 0;
	}
	my $same = &compare($a->{$key}, $b->{$key});
	if (!$same) {
	  return 0;
	}
      }
    } elsif ($ar eq "ARRAY") {
      if ($#a != $#b) {
	return 0;
      }
      for (my $i = 0 ; $i <= $#a ; $i++) {
	my $same = &compare($a[$i], $b[$i]);
	if (!$same) {
	  return 0;
	}
      }
    }
  } else {
    if (defined $br) {
      return 0;
    }
    
    if ($a ne $b) {
      return 0;
    }
  }
  return 1;
}


# Local Variables:
# mode: cperl
# End:
