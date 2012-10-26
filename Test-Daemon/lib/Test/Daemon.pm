package Test::Daemon;
use strict;

our $VERSION = '0.02'

__END__

=head1 NAME

Test::Daemon - Framework for test execution

=head1 Information provided to loggers by framework

In addition to information returned from collect info methods of deployments,
there are following information provided by the framework:

=head2 Test::Daemon::result

Sum of run methods return values or
  -1 if the test case hasn't been run, becouse one of prerun steps failed
  -2 if one of the run methods crashed
  -3 if the run method has 

=head2 Test::Daemon::finished

True if all prerun, precollect and postcollect steps passed.

=head2 Test::Daemon::time

How long run methods were running.

=head2 Test::Daemon::started

Seconds since epoch indicating when executing run methods started.

=head2 Test::Daemon::completed

Seconds since epoch indicating when executing run methods finnished.

=head2 Test::Daemon::resources

Names of resources used to execute the test case.

=head2 Test::Daemon::TestCase::name

Name of the test case as provided by get_info method. If the name is not 
provided, framework generated name based on file name is returned.

=head2 Test::Daemon::TestCase::testset

Name of the test set executed test case is comming from.

=head2 Test::Daemon::TestCase::environment

Name of the environment in which the test case was run.

=head2 Test::Daemon::TestCase::*

All information returned by get_info (see get_info argument of
L<Test::Daemon::TestSet> constructor) are available with prefix
"Test::Daemon::TestSet::". 

=head1 Loggers

There are generic loggers available in the framework:

=head2  L<Test::Daemon::Logger::DBI> 

Log information into any SQL database supported by L<DBI>.

=head2  L<Test::Daemon::Logger::TestSetJUnit>

Create an JUnit result file for every testcase run. This is suitable for 
integration with F<http://www.jenkins.org/> or other continuous integration 
tool.

=head2  L<Test::Daemon::Logger::TestSetSchedule>

This logger outputs a schedule in which test cases were run. The schedule is
in HTML format.

=head1 Deployments

=head2  L<Test::Daemon::Deployment::Exec>

This deployment provides just run method, which set environment variables 
according to resources and execute a test case file.

=head1 AUTHOR

Petr Malat E<lt>oss@malat.bizE<gt>

=head1 COPYRIGHT

Copyright (c) 2011 - 2012 by Petr Malat E<lt>oss@malat.bizE<gt>

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
See F<http://www.perl.com/perl/misc/Artistic.html>.
