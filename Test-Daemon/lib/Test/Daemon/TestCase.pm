package Test::Daemon::TestCase;
use strict;

use Test::Daemon::Object;

our @ISA = qw(Test::Daemon::Object);
our @MANDATORY_ARGS = qw(name testset info);
our $VERSION = 0.01;
our %default = (environment => 'default', shared_resources => {}, exclusive_resources => {});

sub init {
	my $self = shift;
	my %args = @_;

	$self->{name} = delete $args{name};
	$self->{info} = delete $args{info};
	$self->{info}{testset} = $args{testset}{name};
	$self->{info}{name} = $self->{name};

	while (my ($k, $v) = each %default) {
		$self->{info}{$k} = $v unless defined $self->{info}{$k};
	}

	return $self;
}

sub get_info ($$) {
	my ($self, $attr) = @_;

	return $self->{info}{$attr};
}

sub export_info ($$) {
	my ($self, $info) = @_;

	while (my ($k, $v) = each %{$self->{info}}) {
		$info->{'Test::Daemon::TestCase::' . $k} = $v;
	}
}

sub name ($) {
	return $_[0]->{name};
}

1;

__END__

=head1 NAME

Test::Daemon::TestCase - Represent one test case

=head1 DESCRIPTION

This module abstracts a test case in the framework. 

=head1 METHODS

=head2 new

=head1 SEE ALSO

L<Test::Daemon> - Test::Daemon framework documentation index.

L<Test::Daemon::TestSet> - Set of test cases

=head1 AUTHOR

Petr Malat <oss@malat.biz>

=head1 COPYRIGHT

Copyright (c) 2011 - 2012 by Petr Malat E<lt>oss@malat.bizE<gt>

This program is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.
See F<http://www.perl.com/perl/misc/Artistic.html>.
