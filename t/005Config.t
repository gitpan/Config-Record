# $Id: 005Config.t,v 1.2 2004/04/01 19:32:57 dan Exp $

BEGIN { $| = 1; print "1..8\n"; }
END { print "not ok 1\n" unless $loaded; }

use Config::Record;
use Carp qw(confess);
use File::Temp qw(tempfile);
use IO::File;

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

unlink $file;

# Finally test the constructor with bogus ref

my $bogus = {};
bless $bogus, "Bogus";
eval "Config::Record->new(file => $bogus)";
print "not " unless $@;
print "ok 8\n";

# Local Variables:
# mode: cperl
# End:
