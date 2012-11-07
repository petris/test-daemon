package Test::Daemon::Environment;
use strict;

use Test::Daemon::Object;
use File::Path qw(make_path);
use List::Util qw(first max maxstr min minstr reduce shuffle sum);
use AnyEvent;
use AnyEvent::Process;
use autodie;

our @ISA = qw(Test::Daemon::Object);
our @MANDATORY_ARGS = qw(name deployments resources);
our $VERSION = 0.01;

our $CRASHED = 63;
our $KILLED = 9;

sub init {
	my $self = shift;
	my %args = @_;

	# Mandatory arguments
	$self->{name}        = $args{name};
	$self->{resources}   = $args{resources};
	$self->{deployments} = $self->create_deployments($args{deployments});

	# Optional arguments
	$self->{provided_resources}  = $args{provided_resources}  || {};
	$self->{deploy_steps}        = $args{deploy_steps}        || [];
	$self->{prerun_steps}        = $args{prerun_steps}        || [];
	$self->{precollect_steps}    = $args{precollect_steps}    || [];
	$self->{postcollect_steps}   = $args{postcollect_steps}   || [];

	# Default values for deployments
	$self->{default_step_timeout}       = 900;
	$self->{default_step_check_timeout} = 180;
	while (my ($k, $v) = each %args) {
		$self->{$k} = $v if $k =~ /^default_/;
	}
}

sub create_deployments($$) {
	my ($self, $deployments) = @_;
	my @rtn;

	foreach my $d (@$deployments) {
		(my $import = $d->[0] . '.pm') =~ s/::/\//g;
		require $import;

		my $args = $d->[1] || {};

		no strict 'refs';
		push @rtn, $d->[0]->new(%$args, resources => $self->{resources}, deployments => \@rtn);
	}

	return \@rtn;
}

sub deployment_get_value {
	my $self = shift;
	my $deployment = shift || die;
	my $value      = shift || die;
	
	if ($deployment->can($value)) {
		no strict 'refs';
		return $deployment->$value(@_);
	} elsif (defined $deployment->{$value}) {
		return $deployment->{$value};
	} elsif (defined $self->{"default_$value"}) {
		return $self->{"default_$value"};
	} else {
		return undef;
	}
}

sub deployments_do {
	my $self = shift;
	my $resources = shift;
	my $func = shift || die;
	my $parallel = shift;
		
	$self->log('Running ' . "$func with " . scalar @_ . ' arguments.');

	die unless defined $parallel;

	return $parallel ? $self->deployments_do_in_children($resources, $func, $parallel, @_) : 
	                   $self->deployments_do_in_current($resources, $func, @_);
}

sub deployments_do_in_current {
	my $self = shift;
	my $resources = shift;
	my $func = shift || die;
	my @rtn;

	# Run deployment functions
	foreach my $deployment (@{$self->{deployments}}) {
		if ($deployment->can($func)) {
			my ($pid, $orig_out, $orig_err);
			eval {
				my $remaining = $self->deployment_get_value($deployment, $func . '_step_timeout') ||
						$self->deployment_get_value($deployment, 'step_timeout', $func);
				my $step_check_timeout;

				if ($deployment->can('running')) {
					$step_check_timeout = $self->deployment_get_value($deployment, $func . '_step_check_timeout') ||
							      $self->deployment_get_value($deployment, 'step_check_timeout', $func);
				} else {
					$step_check_timeout = $remaining;
				}

				local $SIG{ALRM} = sub {
					$remaining -= $step_check_timeout;
					if ($remaining <= 0) {
						$self->err("Function run takes too long - interrupting");
					} else {
						if ($deployment->running($func, @_)) {
							$self->log("Function running returned true - continuing");
							alarm ($remaining < $step_check_timeout ? $remaining : $step_check_timeout);
						} else {
							$self->err("Function running returned false - interrupting");
						}
					}
				};

				alarm $step_check_timeout;

				# Start output decorator
				my ($pipe_stdout_r, $pipe_stdout_w);
				my ($pipe_stderr_r, $pipe_stderr_w);
				pipe $pipe_stdout_r, $pipe_stdout_w;
				pipe $pipe_stderr_r, $pipe_stderr_w;
				$pid = fork;
				if ($pid == 0) {
					my $out_prefix = $deployment->out_prefix();
					my ($stdout_reader, $stderr_reader);
					$stdout_reader = AE::io $pipe_stdout_r, 0, sub {
						my $line = <$pipe_stdout_r>;
						if (defined $line) {
							print STDOUT $out_prefix, ': ', $line;
						} else {
							undef $stdout_reader;
						}
					};
					$stderr_reader = AE::io $pipe_stderr_r, 0, sub {
						my $line = <$pipe_stderr_r>;
						if (defined $line) {
							print STDERR $out_prefix, ': ', $line;
						} else {
							undef $stderr_reader;
						}
					};
					AE::cv->recv();
					exit 0;
				}

				local $0 = 'TD ' . ref($deployment) . '::' . $func;
				$self->log('Running ' . ref($deployment) . "::$func");
				open $orig_out, '>&', *STDOUT;
				open $orig_err, '>&', *STDERR;
				open STDOUT, '>&', $pipe_stdout_w;
				open STDERR, '>&', $pipe_stderr_w;
				no strict 'refs';
				push @rtn, $deployment->$func(@_);
				alarm 0;
			}; my $err = $@;
			open STDOUT, '>&', $orig_out if defined $orig_out;
			open STDERR, '>&', $orig_err if defined $orig_err;
			if (defined $pid) {
				kill 9, $pid;
				waitpid $pid, 0;
			}
			if ($err) {
				push @rtn, $err =~ / - interrupting/ ? $KILLED : $CRASHED;
				last;
				#$self->err($@);
			}
		}
	} 

	if ($func eq 'run') {
		return sum @rtn;
	} else {
		return scalar grep $_, @rtn;
	}
}

sub deployments_do_in_children {
	my $self = shift;
	my $resources = shift;
	my $func = shift || die;
	my $jobs = shift || die;
	my @deployments_to_run = @{$self->{deployments}};
	my %child;
	my %rtn;
	my $wait_for_child = AE::cv;	
	local $0 = 'TD executing ' . $func;
	my @argv = @_;
	
	while (scalar @deployments_to_run) {
		if ($jobs > 0) {
			my $deployment = shift @deployments_to_run;
			next unless $deployment->can($func);
			local $deployment->{resources} = $resources;

			$self->log('Processing ' . ref $deployment);
			my $func_name =  ref($deployment) . '::' . $func;

			# Create STDOUT, STDERR and DATA pipe
			my $pref = $deployment->out_prefix();
			if ($self->{name}) {
				$pref = "[$self->{name}]" . $pref;
			}
			my $json_reader; $json_reader = sub {
				my ($handle, $data) = @_;
				AE::log trace => "GET $handle, $data";
				while (my ($k, $v) = each %$data) {
					$deployment->{$k} = $v;
				}
				$handle->push_read(json => $json_reader);
			};

			# Run the child function
			my %job_args = (
				fh_table => [
					\*STDIN     => ['open', '<', '/dev/null'],
					\*STDOUT    => ['decorate', '>', $pref . ': ', \*STDOUT],
					\*STDERR    => ['decorate', '>', $pref . ': ', \*STDERR],
					\*DATA_PIPE => ['pipe', '>', handle => [push_read => [json => $json_reader], on_error => sub {}]],
				],
				on_completion => sub { 
					my ($pid, $status) = @_;

					$rtn{$deployment} = $status;
					$self->log("$func_name returned $status");

					$jobs++;
					$child{$deployment}->close();
					delete $child{$deployment};
					$wait_for_child->send($status);
				},
				code => sub {
					eval {
						select DATA_PIPE; $| = 1;
						select STDERR;    $| = 1;
						select STDOUT;    $| = 1;
						$deployment->{'TESTD_data_pipe'} = \*DATA_PIPE;

						$0 = 'TD ' . $func_name;
						$self->log("Running $func_name ");

						no strict 'refs';
						my $rtn = $deployment->$func(@argv);
						$self->err('CRITICAL', "$func did not return a number") unless $rtn =~ /^\d+$/;
						exit $rtn;
					};
					$self->log("Exceptional exit: $@");
					exit $CRASHED;
				},
				kill_interval => $self->deployment_get_value($deployment, $func . '_step_timeout') ||
						 $self->deployment_get_value($deployment, 'step_timeout', $func),
			);
			if ($deployment->can('running')) {
				$job_args{watchdog_interval} =  $self->deployment_get_value($deployment, $func . '_step_check_timeout') ||
						                $self->deployment_get_value($deployment, 'step_check_timeout', $func);
				$job_args{on_watchdog} = sub { 
					$self->log("Checking if $func_name is running");
					return $deployment->running($func);
				};
			}

			my $job = AnyEvent::Process->new(%job_args);
			$child{$deployment} = $job;
			my $runner = $job->run();
		} else { # Not enought job slots
			my $status = $wait_for_child->recv();
			if ($status == 0) {
				$wait_for_child = AE::cv;
			} else {
				$self->log("Non-zero status, skipping other deployments");
				last;
			}
		}
	}

	# Wait for all children
	while (%child) {
		$wait_for_child->recv();
		$wait_for_child = AE::cv;
	}

	if ($func eq 'run') {
		return sum values %rtn;
	} else {
		return scalar grep $_, values %rtn;
	}
}

sub collect_info($$$$) {
	my ($self, $case, $result, $dir) = @_;
	make_path(map {join '/', $dir, split /::/, ref} @{$self->{deployments}});
	my %info;

	foreach my $dpl (@{$self->{deployments}}) {
		if ($dpl->can('collect_info')) {
			$self->log('Running collect_info on ' . ref $dpl);
			my %subinfo = $dpl->collect_info($case, $result, join '/', $dir, split /::/, ref $dpl);
			$info{ref($dpl) . '::' . $_} = $subinfo{$_} foreach keys %subinfo;
		}
	}

	return %info;
}

sub do_steps {
	my ($self, $stage, $resources, @args) = @_;

	$self->log("Running $stage");
	foreach my $step (@{$self->{$stage . '_steps'}}) {
		$self->log("Running $stage step " . join ' ', @$step, @args);
		if (0 != $self->deployments_do($resources, @$step, @args)) {
			$self->log("Step $step->[0] failed");
			return 1;
		}
	}

	return 0;
}

1;

__END__

=head1 NAME

Test::Daemon::Environment - Package representing an environment.

=head1 DESCRIPTION



=head1 METHODS

=head2 new

Creates new environment instance. Arguments:

=over 4

=item name (mandatory)

Environment name

=item resources (mandatory)

Resources allocated to this environment instance.

=item deployments (mandatory)

Names and arguments for deployment objects used to deploy environment, execute
test cases and collect information in the environment. Format of the attribute
is array of [ name, arguments ] couples, eg:
  deployments => [
      ['Foo::Bar::Deployment', { arg1 => 'value', arg2 => 'value' }],
      ['Foo::Baz::Deployment', {}]
  ]

Arguments specified after the name are passed to the deployment constructor 
when deployment instance is created.

=item provided_resources (optional, default {})

Resources provided by this environment. Argument is hash of resource name =>
resource arguments pairs. Resource arguments are passed to the 
L<Test::Daemon::Resource> constructor, example:
  provided_resources => {
      tested_server_instance_1 => {
          provides  => ['tested_server'],
          variables => {port => 1080}
      },
      tested_server_instance_2 => {
          provides  => ['tested_server'],
          variables => {port => 1081}
      }
  }

=item deploy_steps, prerun_step, precollect_steps, postcollect_steps (optional,
default [])

Value of any of these arguments is an array of arrays, where every inner array 
specifies one deployment method, how many children can be used to execute this
method and additional arguments passed to the method when it is called. Note 
that for parallel execution of a step, there must be more than one deployment
providing that method. Example of argument:
  deploy_steps => [
      ['clean',  10],
      ['deploy', 10, version => 'trunk'],
      ['start',   1],
  ]

Methods are executed in the order they are specified and two methods of 
different name are never executed in parallel in one environment.

=item default_step_timeout (optional, default 900)

Time specified in seconds after which executed deployment method is interrupted.

Deployment can override this by providing step_timeout method or attribute. If
a method is provided, it receives step name as argument and it is expected to 
return step timeout in seconds.

=item default_step_check_timeout (optional, default 180)

Time specified in seconds after which running method of deployment is executed
if it is available and there is executing deployment method. If this method
returns false, executed method is interrupted.

Deployment can override this by providing step_timeout method or attribute. If
a method is provided, it receives step name as argument and it is expected to 
return step timeout in seconds.

=item default_* (optional)

Similar to default_step_timeout and default_step_check_timeout, but it can
be specified per method. To set step timeout for run method, use 
default_run_step_timeout argument.

Again, a deployment can overide it using a method or attribute.

=back

=head1 SEE ALSO

L<Test::Daemon> - Test::Daemon framework documentation index.

L<Test::Daemon::Runner> - Executes deployment methods in environments.

L<Test::Daemon::Object> - Allows specifiing constructor arguments in 
configuration a file.

=head1 AUTHOR

Petr Malat <oss@malat.biz>

=head1 COPYRIGHT

Copyright (c) 2011 - 2012 by Petr Malat E<lt>oss@malat.bizE<gt>

This program is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.
See F<http://www.perl.com/perl/misc/Artistic.html>.
