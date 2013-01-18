package Test::Daemon::ResourcePool;
use strict;

use Test::Daemon::Object;
use Test::Daemon::Resource;
use AnyEvent;
use Coro;

our @ISA = qw(Test::Daemon::Object);
our @MANDATORY_ARGS = qw(resources);
our $VERSION = 0.01;

sub init {
	my $self = shift;
	my %args = @_;

	$self->{resources} = [];
	$self->{wait_for_job} = AE::cv;
	
	while (my ($name, $prop) = each %{$args{resources}}) {
		my $res = new Test::Daemon::Resource(name => $name, provides => $prop->{provides}, variables => $prop->{variables}, pool => $self);
		push @{$self->{resources}}, $res;
	}

	return $self;
}

sub filter_providers {
	my ($self, $resources, $broken) = @_;
	
	if ($broken) {
		return grep $_->provides(@{$resources}), @{$self->{resources}};
	} else {
		return grep {$_->is_broken == 0 and $_->provides(@{$resources})} @{$self->{resources}};
	}
}

sub _try_get_resources {
	my ($p, $e, $a, $u) = @_;

	foreach my $name (keys %$p) {
		my $resources = $p->{$name};
		next if defined $a->{$name};
		foreach my $resource (@$resources) {
			next if defined $u->{$resource};
			$a->{$name} = $resource;
			if (defined $e->{$name}) {
				# Exclusive alloc -> Mark resource as allocated
				$u->{$resource} = $name;
			}
			return 1 if _try_get_resources($p, $e, $a, $u);
			delete $a->{$name};
			delete $u->{$resource};
		}
		return 0;
	}

	return 1;
}

# Required resources are in the form {name1 => ['PROVIDE1', 'PROVIDE2'], name2 => ['PROVIDE3']}
sub try_get_resources($$$) {
	my ($self, $exclusive, $shared) = @_;
	my $alloc = {};
	
	# Check, if it is possible to alloc
	while (my ($name, $resources) = each %$exclusive) {
		$alloc->{$name} = [$self->filter_providers($resources, 1)];
	}
	while (my ($name, $resources) = each %$shared) {
		$self->err("Resource $name is specified both shared and exclusive") if defined $alloc->{$name};
		$alloc->{$name} = [$self->filter_providers($resources, 1)];
	}

	# Try to alloc
	unless (_try_get_resources($alloc, $exclusive, {}, {})) {
		$self->err('Unable to fullfill resource requirements');
		return undef;
	}

	# Allocate resources
	$alloc = {};
	while (my ($name, $resources) = each %$exclusive) {
		$alloc->{$name} = [grep $_->available_exclusive(), $self->filter_providers($resources)];
	}
	while (my ($name, $resources) = each %$shared) {
		$alloc->{$name} = [grep $_->available_shared(), $self->filter_providers($resources)];
	}

	my $assigned = {};
	unless (_try_get_resources($alloc, $exclusive, $assigned, {})) {
		return undef;
	}
	foreach my $name (keys %$exclusive) {
		$assigned->{$name}->alloc_exclusive();
	}
	foreach my $name (keys %$shared) {
		$assigned->{$name}->alloc_shared();
	}

	return $assigned;
}

sub free_resources {
	my $self = shift;

	if (ref $_[0] eq 'ARRAY') {
		map $_->free(), @{$_[0]};
	} elsif (ref $_[0] eq 'HASH') {
		map $_->free(), values %{$_[0]};
	} else {
		map $_->free(), @_;
	}
}

sub reschedule {
	$_[0]->{wait_for_job}->send();
}

sub process_jobs($$$) {
	my ($self, $remaining, $arg) = @_;

	my @jobs;
	while (@$remaining) {
		my $started = 0;
		for (my $index = $#$remaining; $index >= 0; --$index) {
			my $job = $remaining->[$index];
			my $resources = $self->try_get_resources($job->get_exclusive($arg), $job->get_shared($arg));
			next unless defined $resources;

			# Check if this job can be run more than one time
			my $to_do = $job->more_to_do($arg);
			if ($to_do <= 0) {
				splice @$remaining, $index, 1;
				if ($to_do < 0) {
					$self->free_resources($resources);
					next;
				}
			}

			$job->pre_run($arg);

			# Run the job one time
			push @jobs, async {
				# Do the job with resources
				$job->run($resources, $arg);

				# Free resources
				$self->free_resources($resources);
				$self->{wait_for_job}->send();

				# Finnish
				$job->post_run($arg);
			};

			$started++;
		}
		if ($started == 0 && @$remaining) {
			my $status = $self->{wait_for_job}->recv();
			$self->{wait_for_job} = AE::cv;
		}
	}

	$_->join() foreach @jobs;
}

1;

__END__

=head1 NAME

Test::Daemon::ResourcePool - Manages resources

=head1 DESCRIPTION

This module abstracts a resource pool in the framework. It allocates resources
and tracks, which are used.

=head1 METHODS

=head2 new

=head1 SEE ALSO

L<Test::Daemon> - Test::Daemon framework documentation index.

L<Test::Daemon::Resource> - Managed resource

=head1 AUTHOR

Petr Malat <oss@malat.biz>

=head1 COPYRIGHT

Copyright (c) 2011 - 2012 by Petr Malat E<lt>oss@malat.bizE<gt>

This program is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.
See F<http://www.perl.com/perl/misc/Artistic.html>.
