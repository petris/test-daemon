package Test::Daemon::Job::Environment;
use strict;

use Test::Daemon::Object;
use Test::Daemon::Environment;

our @ISA = qw(Test::Daemon::Object);
our @MANDATORY_ARGS = qw(environment name testjobs);

sub init {
	my $self = shift;
	my %args = @_;

	$self->copy_args(%args);
	$self->{num} = 0;
	$self->{tries} = 0;
	$self->{tries_max} = scalar @{$self->{testjobs}};
}

sub pre_run {
	my ($self, $arg) = @_;

	$self->{num}++;
}

sub run($$$) {
	my ($self, $resources, $arg) = @_;
	my $rtn = -1;

	my $num = $self->{tries}++;
	$self->log("Starting job $self->{name}/$num");

	RUN: {
		# Create environment instance
		my $env = new Test::Daemon::Environment(
			%{$self->{environment}},
			runner      => $self->{runner},
			resources   => $resources, 
			name        => "$self->{name}/$num");

		last RUN if $env->do_steps('deploy', $resources);

		# Run testcases, use environment resources
		my $rp = new Test::Daemon::ResourcePool(resources => $self->{environment}{provided_resources});
		$rtn = $rp->process_jobs($self->{testjobs}, $env);
	};

	$self->log("Finnished job $self->{name}/$num");
	$self->{num}--;

	return $rtn;
}

sub post_run($$) {
}

sub more_to_do($$) {
	my $self = shift;
	my $tc_count = scalar @{$self->{testjobs}};

	$self->log("Job $self->{name} has $tc_count testcases to run, currently running in $self->{num} instances.");

	if ($tc_count == 0) {
		return -1;
	} else {
		return $self->{num} < $tc_count && $self->{tries} < $self->{tries_max};
	}
}

sub get_exclusive($$) {
	my $self = shift;
	return $self->{environment}{exclusive_resources};
}

sub get_shared($$) {
	my $self = shift;
	return $self->{environment}{shared_resources};
}

1;

__END__

=head1 NAME

Test::Daemon::Job::Environment - Allows processing of environments in resource pool

=head1 DESCRIPTION

=head1 METHODS

=head2 new

=head1 SEE ALSO

L<Test::Daemon> - Test::Daemon framework documentation index.

L<Test::Daemon::ResourcePool> - Process this job

=head1 AUTHOR

Petr Malat <oss@malat.biz>

=head1 COPYRIGHT

Copyright (c) 2011 - 2012 by Petr Malat E<lt>oss@malat.bizE<gt>

This program is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.
See F<http://www.perl.com/perl/misc/Artistic.html>.
