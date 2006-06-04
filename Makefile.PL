# $Id: Makefile.PL,v 1.3 2006/01/27 16:25:50 dan Exp $
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

sub test {
    my $self = shift;
    my $mm_test = $self->SUPER::test(@_);
    
    return '
TO_TEST_PM = $(TO_INST_PM:lib/%.pm=blib/test/%.pm.tstamp)

test :: test-syntax

test-syntax: pure_all $(TO_TEST_PM)

blib/test/%.pm.tstamp: lib/%.pm
	@echo -n "Checking $<: "
	@perl -I blib/lib -c $<
	@podchecker `echo $< | sed -e \'s/\.pm/.pod/\' `
	@mkdir -p `dirname $@`
	@touch $@

' . $mm_test;
  }

__END__
