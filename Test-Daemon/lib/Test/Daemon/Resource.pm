package Test::Daemon::Resource;
use Test::Daemon::Object;
use strict;

our @ISA = qw(Test::Daemon::Object);
our @MANDATORY_ARGS = qw(name provides);
our $VERSION = 0.01;

sub init {
	my $self = shift;
	my %args = @_;

	$self->{name}      = $args{name};
	$self->{provides}  = $args{provides};
	$self->{variables} = $args{variables} || {};
	$self->{counter}   = 0;

	return $self;
}

sub available_shared($) {
	return $_[0]->{counter} >= 0;
}

sub available_exclusive($) {
	return $_[0]->{counter} == 0;
}

sub alloc_shared($) {
	$_[0]->{counter}++;
}

sub alloc_exclusive($) {
	$_[0]->{counter} = -1;
}

sub free($) {
	if ($_[0]->{counter} == -1) {
		$_[0]->{counter} = 0;
	} else {
		$_[0]->{counter}--;
	}
}

sub get_var($$) {
	my ($self, $var) = @_;
	
	if (defined $self->{variables}{$var}) {
		return $self->{variables}{$var};
	} else {
		$self->err('Variable ' . $var . ' is not defined');
		return undef;
	}
}

sub provides {
	my $self = shift;

	foreach my $resource (@_) {
		return 0 unless scalar grep $_ eq $resource, @{$self->{provides}};
	}
	return 1;
}

1;

__END__

=head1 NAME

Test::Daemon::Resource - One resource used by the framework

=head1 DESCRIPTION

This module abstracts a resource in the framework. Resources are managed in 
resource pools.

=head1 METHODS

=head2 new

=head1 SEE ALSO

L<Test::Daemon> - Test::Daemon framework documentation index.

L<Test::Daemon::ResourcePool> - Pool managing resources.

=head1 AUTHOR

Petr Malat <oss@malat.biz>

=head1 COPYRIGHT

Copyright (c) 2011 - 2012 by Petr Malat E<lt>oss@malat.bizE<gt>

This program is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.
See F<http://www.perl.com/perl/misc/Artistic.html>.
