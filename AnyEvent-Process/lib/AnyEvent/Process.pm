package AnyEvent::Process::Job;
use strict;

sub new {
	my ($ref, $pid) = @_;
	my $self = bless {pid => $pid, cbs => [], handles => []}, $ref;

	return $self;
}

sub kill {
	my ($self, $signal) = @_;

	return kill $signal, $self->{pid};
}

sub add_cb {
	my ($self, $cb) = @_;
	push @{$self->{cbs}}, $cb;
}

sub add_handle {
	my ($self, $handle) = @_;
	push @{$self->{handles}}, $handle;
}

sub close {
	my $self = shift;
	foreach (@{$self->{handles}}) {
		undef $_;
	}
}

package AnyEvent::Process;
use strict;

use AnyEvent::Handle;
use AnyEvent::Util;
use AnyEvent;
use Carp;

our @proc_args = qw(fh_table code on_completion args);
our $VERSION = '0.01';

sub new {
	my $ref = shift;
	my $self = bless {}, $ref;
	my %args = @_;

	foreach my $arg (@proc_args) {
		$self->{$arg} = delete $args{$arg} if defined $args{$arg};
	}

	if (%args) {
		croak 'Unknown arguments: ' . join ', ', keys %args;
	}

	return $self;
}

sub run {
	my $self = shift;
	my %args = @_;
	my %proc_args;
	my @fh_table;
	my @handles;

	# Process arguments
	foreach my $arg (@proc_args) {
		$proc_args{$arg} = $args{$arg} // $self->{$arg};
		delete $args{$arg} if defined $args{$arg};
	}

	if (%args) {
		croak 'Unknown arguments: ' . join ', ', keys %args;
	}

	# Handle fh_table
	for (my $i = 0; $i < $#{$proc_args{fh_table}}; $i += 2) {
		my ($handle, $args) = @{$proc_args{fh_table}}[$i, $i + 1];
		unless (ref $handle eq 'GLOB' or $handle =~ /^\d{1,4}$/) {
			croak "Every second element in 'fh_table' must be " . 
					"GLOB reference or file descriptor number";
		}
		if ($args->[0] eq 'pipe') {
			my ($my_fh, $child_fh);

			if ($args->[1] eq '>') {
				($my_fh, $child_fh) = portable_pipe;
			} elsif ($args->[1] eq '<') {
				($child_fh, $my_fh) = portable_pipe;
			} elsif ($args->[1] eq '+>' or $args->[1] eq '+<') {
				($child_fh, $my_fh) = portable_socketpair;
			} else {
				croak "Invalid mode '$args->[1]'";
			}

			unless (defined $my_fh && defined $child_fh) {
				croak "Creating pipe failed";
			}

			push @fh_table, [$handle, $child_fh];
			if (ref $args->[2] eq 'GLOB') {
				open $args->[2], '+>&', $my_fh;
				close $my_fh;
			} elsif ($args->[2] eq 'handle') {
				push @handles, [$my_fh, $args->[3]];
			}

			next;
		}
		if ($args->[0] eq 'open') {
			open my $fh, $args->[1], $args->[2];
			unless (defined $fh) {
				croak "Opening file failed";
			}
			push @fh_table, [$handle, $fh];
			next;
		}
		croak "Unknown redirect type '$args->[0]'";
	}

	# Start child
	my $pid = fork;
	my $job;
	unless (defined $pid) {
		croak "Fork failed: $!";
	} elsif ($pid == 0) {
		# Duplicate FDs
		foreach my $dup (@fh_table) {
			open $dup->[0], '+>&', $dup->[1];
			close $dup->[1];
		}

		# Close handles
		foreach my $dup (@handles) {
			close $dup->[0];
		}

		# Run the code
		my $rtn = $proc_args{code}->(@{$proc_args{args} // []});
		exit ($rtn eq int($rtn) ? $rtn : 1);
	} else {
		$job = new AnyEvent::Process::Job($pid);

		# Close FDs
		foreach my $dup (@fh_table) {
			close $dup->[1];
		}

		# Create handles
		foreach my $handle (@handles) {
			my (@hdl_args, @hdl_calls);
			for (my $i = 0; $i < $#{$handle->[1]}; $i += 2) {
				if (AnyEvent::Handle->can($handle->[1][$i] and 'ARRAY' eq ref $handle->[1][$i+1])) {
					push @hdl_calls, [$handle->[1][$i], $handle->[1][$i+1]];
				} else {
					push @hdl_args, $handle->[1][$i] => $handle->[1][$i+1];
				}
			}
			my $hdl = AnyEvent::Handle->new(fh => $handle->[0], @hdl_args);
			foreach my $call (@hdl_calls) {
				no strict 'refs';
				my $method = $call->[0];
				$hdl->$method(@{$call->[1]});
			}
			$job->add_handle($hdl);
		}

		# Create callbacks
		if (defined $proc_args{on_completion}) {
			$job->add_cb(AE::child $pid, $proc_args{on_completion});
		}
		$self->{job} = $job;
	}

	return $job;
}

sub kill {
	my ($self, $signal) = @_;

	croak 'No process was started' unless defined $self->{job};
	return $self->{job}->kill($signal);
}

sub close {
	my $self = shift;

	croak 'No process was started' unless defined $self->{job};
	return $self->{job}->close();
}

1;

__END__

=head1 NAME

AnyEvent::Process - Start process and watch for events 

=head1 DESCRIPTION

This module starts an process

=head1 METHODS

=head2 new

=head1 SEE ALSO

L<AnyEvent> - Event framework for PERL.

L<AnyEvent::Subprocess> - Similiar module, but with more dependencies and little
more complicated usage.

=head1 AUTHOR

Petr Malat <oss@malat.biz>

=head1 COPYRIGHT

Copyright (c) 2012 by Petr Malat E<lt>oss@malat.bizE<gt>

This program is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.
See F<http://www.perl.com/perl/misc/Artistic.html>.
