# $Id: Makefile.PL,v 1.2 2004/04/01 19:32:57 dan Exp $
# -*- perl -*-

use ExtUtils::MakeMaker;

WriteMakefile(
	      NAME => "Config::Record",
	      VERSION_FROM => 'lib/Config/Record.pm',
	      AUTHOR => "Daniel P. Berrange (dan[at]berrange[dot]com)",
	      dist =>
	      {
	       COMPRESS => 'gzip --force --best',
	      },

	      clean =>
	      {
	       FILES => '*.bak *~',
	      },
	      
	      depend => {
	        Makefile => '$(VERSION_FROM)',
	        Config-Record.spec => '$(VERSION_FROM)',
		dist => 'Config-Record.spec',
	      },
	      
	      realclean => {
	       FILES => 'Config-Record-*.tar.gz Config-Record.spec',
	      }
	     );

package MY;

sub libscan
  {
    my ($self, $path) = @_;
    ($path =~ /\~$/) ? undef : $path;
  }

__END__
