package Test::Daemon;
use strict;

use Test::Daemon::Object;
use Test::Daemon::ResourcePool;
use Test::Daemon::Runner;

use Socket qw(SOL_SOCKET SO_REUSEADDR);
use AnyEvent::Socket;
use AnyEvent::Handle;
use List::Util;
use Coro;
use POSIX::AtFork qw(pthread_atfork);

our @ISA = qw(Test::Daemon::Object);
our @MANDATORY_ARGS = qw(provided_resources socket);
our $VERSION = 0.02;
our $HANDLE;

sub tcp_server_prepare {
        my $fh = $_[0];
        setsockopt $fh, SOL_SOCKET, SO_REUSEADDR, 0;
        pthread_atfork undef, undef, sub {close $fh};
}

sub init {
	my $self = shift;
	my %args = @_;

	my @c = parse_hostport($args{socket});
	$self->{provided_resources} = new Test::Daemon::ResourcePool(resources => $args{provided_resources});
	$self->{socket}      = tcp_server $c[0], $c[1], 
					sub {
						pthread_atfork undef, undef, sub {close $_[0]}; 
						$self->on_accept(@_);
					}, \&tcp_server_prepare;
	$self->{connections} = [];
	$self->{runners}     = {};
	$self->{exit_after}  = $args{exit_after};
	
	return $self;
}

sub on_accept {
	my ($self, $fh) = @_;

	my $reader = sub {
		my ($handle, $msg) = @_;

		unless ('HASH' eq ref $msg &&
			1 == scalar keys %$msg &&
			'ARRAY' eq ref List::Util::first {1} values %$msg) {
			$self->close($handle, -1, 'Message must be in a form { method => [arguments...] }');
			return;
		}

		my ($method, $args) = %$msg;
		unless ($self->can('on_msg_' . $method)) {
			$self->close($handle, -2, "Method $method is not supported");
			return;
		}

		my ($rtn_msg, $rtn_data);
		{
			$method = 'on_msg_' . $method; 
			local $HANDLE = $handle;
			no strict 'refs';
			($rtn_msg, $rtn_data) = $self->$method(@$args);
		}

		return unless defined $rtn_msg;

		if ($rtn_msg eq 'error' && $rtn_data->{number} < 0) {
			$self->close($handle, $rtn_data->{number}, $rtn_data->{message});
		} else {
			$handle->push_write(json => {$rtn_msg => $rtn_data});
		}
	};

	my $handle = new AnyEvent::Handle(
		fh => $fh,
		on_eof   => sub {  
			$self->_close($_[0]);
			$_[0]->push_shutdown;
		},
		on_read  => sub {
			$_[0]->push_read(json => $reader);
		}
	);

	push @{$self->{connections}}, $handle;

	return 0;
}

sub _close {
	my ($self, $handle) = @_;
	for (my $i = 0; $i <= $#{$self->{connections}}; $i++) {
		if ($self->{connections}[$i] == $handle) {
			splice @{$self->{connections}}, $i, 1;
			last;
		}
	}	
}

sub close {
	my ($self, $handle, $err, $msg) = @_;
	$handle->push_write(json => { 
			error => { 
				number => $err,
				message => $msg,
			}
		});
	$handle->push_shutdown();
}

sub on_msg_run {
	my $self = shift;

	# Create runner arguments
	my %runner_args = @_;


	unless (defined $runner_args{provided_resources}) {
		$runner_args{provided_resources} = $self->{provided_resources};
	}

	# Runner id
	my $id;
	my $time = time;
	for (my $i = 0; 1; $i++) {
		unless (defined $self->{runners}{$time + $i}) {
			$id = $time + $i;
			last;
		}
	}
	$runner_args{id} = $id;

	# Create runner
	my $runner;
	eval {
		$runner = new Test::Daemon::Runner(%runner_args);
		$self->{runners}{$id} = $runner;
	}; if ($@) {
		return error => { number => -3, message => $@ };
	}

	async {
		my ($result, $msg);

		eval {
			$runner->run();
			$msg = 'Runner exited succesfully';
			$result = 0;
		}; if ($@) {
			$msg = $@;
			$result = 1;
		}

		delete $self->{runners}{$id};

		foreach my $handle (@{$runner->{tdc_waiters} || []}) {
			$handle->push_write(json => {
				ok => {
					result => $result,
					message => $msg,
				}
			});
		}

		if (defined $self->{exit_after}) {
			if (--$self->{exit_after} <= 0) {
				exit 0 if 0 == scalar keys %{$self->{runners}};
			}
		}
	};

	return ok => { message => 'Runner scheduled', id => $id };
}

sub on_msg_status {
	my $self = shift;

	my %status = ( 
		runners => {},
		resources => {},
		time => time,
		pid => $$,
	);

	$status{exit_after} = $self->{exit_after} if defined $self->{exit_after};
	
	foreach my $runner_id (keys %{$self->{runners}}) {
		my $runner = $self->{runners}{$runner_id};
		$status{runners}{$runner_id} = {
			total => $runner->{total},
			name  => $runner->{name},
			pass  => $runner->{pass},
			fail  => $runner->{fail},
			cancelling  => $runner->{cancelling} // 0,
		};
	}
	
	foreach my $resource (@{$self->{provided_resources}{resources}}) {
		$status{resources}{$resource->{name}} = {
			counter => $resource->{counter},
			broken  => $resource->{broken},
		};
	}

	return ok => \%status;
}

sub on_msg_wait {
	my ($self, $job_id) = @_;

	unless (defined $self->{runners}{$job_id}) {
		return error => { number => -9, message => "Job id '$job_id' is not running" };
	}

	push @{$self->{runners}{$job_id}{tdc_waiters}}, $HANDLE;

	return undef;
}

sub on_msg_cancel {
	my ($self, $job_id) = @_;

	unless (defined $self->{runners}{$job_id}) {
		return error => { number => -9, message => "Job id '$job_id' is not running" };
	}

	$self->{runners}{$job_id}->cancel();
	return ok => { message => 'Cancelling in progress' };
}

sub on_msg_quit {
	exit 0;
}

1;
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
