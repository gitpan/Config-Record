# $Id: 005Config.t,v 1.3 2004/05/14 13:44:49 dan Exp $

BEGIN { $| = 1; print "1..17\n"; }
END { print "not ok 1\n" unless $loaded; }

use warnings;
use Config::Record;
use Carp qw(confess);
use File::Temp qw(tempfile);
use IO::File;

no warnings 'Config::Record';

$loaded = 1;
print "ok 1\n";

my $config = <<EOF;
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
  wibble = {
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
EOF

my ($fh, $file) = tempfile("tmpXXXXXXX", UNLINK => 1);
print $fh $config;
close $fh;

# First test the constructor with a filename
my $cfg = Config::Record->new(file => $file);

# Test plain string
print "not " unless $cfg->param("name") eq "Foo";
print "ok 2\n";

# Test quoted string
print "not " unless $cfg->param("title") eq "Wizz bang wallop";
print "ok 3\n";

# Test defaults
print "not " unless $cfg->param("nada", "eek") eq "eek";
print "ok 4\n";

# Now test the constructor with a file handle
$fh = IO::File->new($file);
$cfg = Config::Record->new(file => $fh);

# Test plain string
print "not " unless $cfg->param("name") eq "Foo";
print "ok 5\n";

# Test quoted string
print "not " unless $cfg->param("title") eq "Wizz bang wallop";
print "ok 6\n";

# Test defaults
print "not " unless $cfg->param("nada", "eek") eq "eek";
print "ok 7\n";

# Test with empty constructor & load method

$cfg = Config::Record->new();

# Shouldn't be anything there yet
eval "$cfg->param('name')";
print "not " unless $@;
print "ok 8\n";

# Lets set an option
$cfg->set("name" => "Blah");
print "not " unless $cfg->param("name") eq "Blah";
print "ok 9\n";

# Now load the config record
$fh = IO::File->new($file);
$cfg->load($fh);

# Test plain string - should have overwritten 'Blah'
print "not " unless $cfg->param("name") eq "Foo";
print "ok 10\n";

# Test quoted string
print "not " unless $cfg->param("title") eq "Wizz bang wallop";
print "ok 11\n";

# Test defaults
print "not " unless $cfg->param("nada", "eek") eq "eek";
print "ok 12\n";


# Now write it out to another file....
my ($fh2, $file2) = tempfile("tmpXXXXXXX", UNLINK => 1);
$fh2->close;
$cfg->save($file2);

# ...and then read it back in
my $cfg2 = Config::Record->new(file => $file2);

# Test plain string
print "not " unless $cfg2->param("name") eq "Foo";
print "ok 13\n";

# Test quoted string
print "not " unless $cfg2->param("title") eq "Wizz bang wallop";
print "ok 14\n";

# Test defaults
print "not " unless $cfg2->param("nada", "eek") eq "eek";
print "ok 15\n";

# Now recursively compare entire hash
print "not " unless &compare($cfg->record, $cfg2->record);
print "ok 16\n";

# Finally test the constructor with bogus ref

my $bogus = {};
bless $bogus, "Bogus";
eval "Config::Record->new(file => $bogus)";
print "not " unless $@;
print "ok 17\n";


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
