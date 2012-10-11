package Test::Daemon::Deployment::Exec;
use strict;

use Test::Daemon::Deployment;

our @ISA = qw(Test::Daemon::Deployment);

sub run {
	my ($self, $tc) = @_;

	while (my ($res_name, $res) = each %{$self->{resources}}) {
		while (my ($var_name, $value) = each %{$res->{variables}}) {
			$ENV{$res_name . '_' . $var_name} = $value;
			$ENV{$var_name} = $value;
		}
	}

	exec $tc->get_info('file');
}

sub get_info {
	my $environment = shift;
	$environment =~ s/^.*\/([^\/]+)\/[^\/]+$/$1/;
	$environment = 'default' unless $environment;
	return { 
			environment => $environment,
			exclusive_resources => { 
				running_testcase => ['running_testcase'] 
			}
		};
}

1;

__END__

=head1 NAME

Test::Daemon::Deployment::Exec - Execute test case file

=head1 SYNOPSIS

Example configuration file segment for getinfo method:

    //   ...
    "testsets": {
        //   ...
        "shell_scripts": {
            "root":     "${TESTD_CONFIG_DIR}tests/",
            "run":      [".*\\.sh"],
            "get_info": "Test::Daemon::Deployment::Exec::get_info"
        },
        //   ...
    },
    //   ...

Example configuration file segment deployment usage:

   //   ...
   "deployments": [
      //   ...
      ["Test::Daemon::Deployment::Exec", {}],
      //   ...
   ],
   //   ...

=head1 DESCRIPTION

This is basic deployment designed for test execution. It provides run method,
which executes test file as an executable. It can be used, if test cases are
standalone scripts. Resource variables are made available as environment
variables under their names and also under their names prefixed with the
resource name and underscore. For example: resource 'running_testcase' with 
variable 'id' set to 5 leads to definition of environment variables 'id' and 
'running_testcase_id' with value 5.


It also provides simple get_info method, which set an environment for test
case according to its parent directory. For example for a testcase file 
'/foo/bar/baz/testcase.sh' environment will set to 'baz'. If no such directory
exists, environment is set to 'default'. Also, every test case is made
to require 'running_testcase' resource exclusively to run. This allows to limit
a number of running testcases in an environment by providing apropriate number
of 'running_testcase' resources.

=head1 METHODS

=head2 run

Sets environment variables according to used resources and execute the test 
case.

=head1 FUNCTIONS

=head2 get_info

Return a hash reference with 'exclusive_resources' set to: 
  { running_testcase => ['running_testcase'] }

and 'environment' to set to the name of test case parent directory.

=head1 SEE ALSO

Test::Daemon - Test::Daemon framework documentation index

=head1 AUTHOR

Petr Malat <oss@malat.biz>

=head1 COPYRIGHT

Copyright (c) 2011 - 2012 by Petr Malat E<lt>oss@malat.bizE<gt>

This program is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.
See F<http://www.perl.com/perl/misc/Artistic.html>.
