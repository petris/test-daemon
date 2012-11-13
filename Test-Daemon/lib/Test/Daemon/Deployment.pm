package Test::Daemon::Deployment;
use strict;
use Test::Daemon::Object;
use JSON;

our @ISA = qw(Test::Daemon::Object);
our $VERSION = 0.01;

sub out_prefix {
	my $self = shift || die;

	my $name = ref $self;
	$name =~ s/^.*:://;

	return '[' . $name . ']';
}

sub set_in_master {
	my $self = shift || die;
	my %data = @_;

	if (defined $self->{'TESTD_data_pipe'}) {
		print {$self->{'TESTD_data_pipe'}} to_json({set => \%data});
	} else {
		while (my ($key, $value) = each %data) {
			$self->{$key} = $value;
		}
	}
}

sub call_in_master {
	my $self = shift;
	my $method = shift;

	if (defined $self->{'TESTD_data_pipe'}) {
		print {$self->{'TESTD_data_pipe'}} to_json({call => [[$method, \@_]]});
	} else {
		no strict 'refs';
		$self->$method(@_);
	}
}

1;

__END__

=head1 NAME

Test::Daemon::Deployment - Base class of all deployment objects

=head1 DESCRIPTION

This class provides functionality common to all deployments objects. Any 
deployment object should be (possibly indirectlyt) Test::Daemon::Deployment.

=head1 METHODS

=head2 set_in_master

Because deployment are usually executed in child processes, deployment object
can use this function to remember data between diferent steps.

Arguments of this functions are key => value pairs and calling this function
sets instance attribute to the specified value in master process. 

=head2 out_prefix

When a deployment writes something to STDOUT or STDERR, it is prefixed by
string returned from this method. Deployments can override this method as
needed.

=head1 SEE ALSO

Test::Daemon - Test::Daemon framework documentation index

=head1 AUTHOR

Petr Malat <oss@malat.biz>

=head1 COPYRIGHT

Copyright (c) 2011 - 2012 by Petr Malat E<lt>oss@malat.bizE<gt>

This program is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. 
See F<http://www.perl.com/perl/misc/Artistic.html>.
