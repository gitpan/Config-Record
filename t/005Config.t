# $Id: 005Config.t,v 1.1 2004/02/10 19:03:50 dan Exp $

BEGIN { $| = 1; print "1..4\n"; }
END { print "not ok 1\n" unless $loaded; }

use Cache::MemoryCache;
use Config::Record;
use Carp qw(confess);
use File::Temp qw(tempfile);
	 
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

my $cache = Cache::MemoryCache->new( { namespace => 'Test',
				       default_expires_in => 600 });

my $cfg = Config::Record->new(filename => $file,
                              cache => $cache);


# Test plain string
print "not " unless $cfg->param("name") eq "Foo";
print "ok 2\n";

# Test quoted string
print "not " unless $cfg->param("title") eq "Wizz bang wallop";
print "ok 3\n";

# Test defaults
print "not " unless $cfg->param("nada", "eek") eq "eek";
print "ok 4\n";

unlink $file;

# Local Variables:
# mode: cperl
# End:
