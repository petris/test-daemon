package Test::Daemon::Runner;
use strict;

use Test::Daemon::Object;
use Test::Daemon::ResourcePool;
use Test::Daemon::TestSet;
use Test::Daemon::Job::Environment;
use Test::Daemon::Job::Test;

our @ISA = qw(Test::Daemon::Object);
our @MANDATORY_ARGS = qw(testsets environments provided_resources);
our $VERSION = 0.02;

sub init {
	my $self = shift;
	my %args = @_;

	$self->{resources} = new Test::Daemon::ResourcePool(resources => $args{provided_resources});
	$self->{environments} = $args{environments};
	$self->{environment_testcases} = {};

	# Create test sets
	$self->{testsets} = {};
	$self->{testsets_to_run} = [];
	while (my ($ts_name, $ts_args) = each %{$args{testsets}}) {
		$self->{testsets}{$ts_name} = new Test::Daemon::TestSet(name => $ts_name, %$ts_args);
		push @{$self->{testsets_to_run}}, $ts_name;
	}

	# Assign tests to environments
	$self->{testsets_to_run} = $args{testsets_to_run} if defined $args{testsets_to_run};
	foreach my $ts_name (@{$self->{testsets_to_run}}) {
		my $ts = $self->{testsets}{$ts_name};
		$self->err('CRITICAL', "Test set $ts_name is not defined") unless defined $ts;

		foreach my $env ($ts->get_environments()) {
			$self->{environment_testcases}{$env} = [$ts->get_environment_testcases($env)];
		}
	}

	# Create loggers
	$self->{loggers} = [];
	foreach my $logger (@{$args{loggers}}) {
		(my $import = $logger->[0] . '.pm') =~ s/::/\//g;
		require $import;

		no strict 'refs';	
		push @{$self->{loggers}}, $logger->[0]->new(%{$logger->[1]});
	}
	
	return $self;
}

sub log_testset($$) {
	my ($self, $method) = @_;

	foreach my $logger (@{$self->{loggers}}) {
		foreach my $testset (@{$self->{testsets_to_run}}) {
			no strict 'refs';
			$logger->$method($testset, $self->{testsets}{$testset}) if $logger->can($method);
		}
	}
}

sub run {
	my $self = shift;
	my %remaining;
	my %deployed;
	my @jobs;

	# Create job for every environment we are going to run
	while (my ($env, $tests) = each %{$self->{environment_testcases}}) {
		if (defined $self->{environments}{$env}) {
			push @jobs, new Test::Daemon::Job::Environment(environment => $self->{environments}{$env},
					name => $env, 
					testjobs => [map Test::Daemon::Job::Test->new(tc => $_, loggers => $self->{loggers}), @$tests]);
		} else {
			$self->err("Environment '$env' is not defined");
		}
	}	

	# Run it
	$self->log_testset('testset_start');
	$self->{resources}->process_jobs(\@jobs, undef);
	$self->log_testset('testset_done');
}

1;

__END__

=head1 NAME

Test::Daemon::Runner - Run tests from testsets in their environments 

=head1 SYNOPSIS


=head1 DESCRIPTION

This module is responsible for running all tests from specified test sets. Every
test requires an environment to run in and can use some resources provided by
that environment.

=head2 Resource management and parallel running

To create an environment, some global resources are needed. These resources are 
allocated from "world resources" -- resources, which are specified as 
provided_resources argument of constructor. More instances of one environment
will be created if there is more testcases to run in that environment and if
enough resources are available.

In an environment instance, reources provided by that environment exists. To run
a testcase in that environment, there must be enough resources for it. Also if 
there is enough resources two or more testcases can be run in parallel.

Both environment and test case can specify if it requires particular resource
in shared or exclusive mode. If a resource is required in exclusive mode, only
one environment or test case will use it. If it is required in shared mode, then
it can be used by more tests or environments at the same time.

=head2 Creating environments

After resources required for an environment are allocated, enviroment creation
can start. Every environment is created using deployment objects by calling
methods specified in deploy_steps. All deploy steps must return 0 or they are
considered to fail and deployment is aborted. See documentation of 
Test::Daemon::Environment for details.

=head2 Running of testcases

After environment is deployed, following is executed for every testcase and 
every deployment:

  All methods specified in prerun_steps
  Methods run
  All methods specified in precollect_steps
  Methods collect_info
  All methods specified in postcollect_steps

Sum of run methods result, information collected by collect_info methods and
some other informations are then passed to the loggers.

All prerun steps must return 0 or they are considered to fail and loop will
start again from beginning with another testcase. Current testcase will return
-1 as its result.

=head2 Logging 

Deployment method collect info is called with a path to directory as argument 
and is expected to store all files it want to make available to loggers in
that directory. Another possibility how to pass information to logers is by 
returning any number of key =E<gt> value pairs.

When logger is run, its method log_info receives two arguments. First argument
is a hash reference, which contains collected key =E<gt> value pairs where each 
key has its deployment type prepended to it. For example if My::Own::Deployment
returns foo =E<gt> 'some_value', it will be available under name 
My::Own::Deployment::foo to loggers. Second argument points to directory where
all files stored by collect_info methods are available. If My::Own::Deployment
stores file log.txt, it will be available as My/Own/Deployment/log.txt to 
loggers.

Loggers can also provide testset_start and/or testset_done methods, which are
executed with test set name as first argument and test set reference as second
argument.

All logger methods are executed in main thread and should not block.

=head1 SEE ALSO

L<Test::Daemon> - Test daemon main object and starting point of documentation

L<Test::Daemon::Object> - Base class, used for reading arguments from file,
logging etc.

L<Test::Daemon::Environment> - Represents an environment in which test cases
are run

L<Test::Daemon::Deployment> - All user provided deployments should use this as
their base class

L<Test::Daemon::TestSet> - Represents a set of tests

=head1 AUTHOR

Petr Malat E<lt>oss@malat.bizE<gt>

=head1 COPYRIGHT

Copyright (c) 2011 - 2012 by Petr Malat E<lt>oss@malat.bizE<gt>

This program is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.
See F<http://www.perl.com/perl/misc/Artistic.html>.
