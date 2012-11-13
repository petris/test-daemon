package Test::Daemon::Job::Test;
use strict;

use Test::Daemon::Object;

our @ISA = qw(Test::Daemon::Object);
our @MANDATORY_ARGS = qw(tc loggers);

sub init {
	my $self = shift;
	my %args = @_;

	$self->{result}    = -1;
	$self->{finnished} = 0;
	$self->{started}   = 0;
	$self->{completed} = 0;
	$self->{tc}        = $args{tc};
	$self->{loggers}   = $args{loggers};
}

sub pre_run {
}

sub run ($$$) {
	my ($self, $resources, $env) = @_;

	$self->{resources} = {%{$env->{resources}}, %$resources};
	$self->{log_dir}   = File::Temp->newdir();

	$self->log("Running TC $self->{tc}{name} with resources: " . join ' ', sort map $_->{name}, values %{$self->{resources}});

	# prerun
	return if $env->do_steps('prerun', $self->{resources}, $self->{tc});

	# run
	$self->{started}   = time;
	$self->{result}    = $env->deployments_do($self->{resources}, 'run', 1, $self->{tc});
	$self->{completed} = time;

	# precollect
	return if $env->do_steps('precollect', $self->{resources}, $self->{tc}, $self->{result});

	# collect
	$self->{info} = {$env->collect_info($self->{tc}, $self->{result}, $self->{log_dir}->dirname())};

	# postcollect
	return if $env->do_steps('postcollect', $self->{resources}, $self->{tc}, $self->{result});

	$self->{finished} = 1;
	$self->log("Finnished TC $self->{tc}{name}");
}

sub post_run ($$) {
	my ($self, $env) = @_;

	# Log results
	$self->{info}{'Test::Daemon::result'}    = $self->{result};
	$self->{info}{'Test::Daemon::finished'}  = $self->{finished};
	$self->{info}{'Test::Daemon::time'}      = $self->{completed} - $self->{started};
	$self->{info}{'Test::Daemon::started'}   = $self->{started};
	$self->{info}{'Test::Daemon::completed'} = $self->{completed};
	$self->{info}{'Test::Daemon::resources'} = join ' ', sort map $_->{name}, values %{$self->{resources}};
	$self->{tc}->export_info($self->{info});

	foreach my $logger (@{$self->{loggers}}) {
		$logger->log_info($self->{info}, $self->{log_dir}->dirname());
	}
}

sub more_to_do($$) {
	return 0;
}

sub get_exclusive($$) {
	my $self = shift;
	return $self->{tc}->get_info('exclusive_resources');
}

sub get_shared($$) {
	my $self = shift;
	return $self->{tc}->get_info('shared_resources');
}

1;

__END__

=head1 NAME

Test::Daemon::Job::Environment - Allows processing of test cases in resource pool

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
