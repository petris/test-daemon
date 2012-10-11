package Test::Daemon::Common;
use strict;

use File::Temp;
use File::Copy;
use Carp;
use Exporter 'import';

our $VERSION = 0.01;
our @EXPORT_OK = qw(load_sub load_sub_unless_sub get_file);

sub load_sub($) {
	my $sub = shift;

	(my ($package, $func)) = $sub =~ /^(.*)::(.*)$/;
	$package =~ s|::|/|g;
	require "$package.pm" or croak "Failed to load $sub";
	return sub {
		no strict 'refs';
		$sub->(@_);
	};
}

sub load_sub_unless_sub($) {
	my $sub = shift;

	if (ref $sub eq '') {
		return load_sub($sub);
	} elsif (ref $sub eq 'CODE') {
		return $sub;
	} else {
		croak "The argument must be a string or code reference";
	}
}

sub get_file($) {
	my $file = shift;
	my $new_file = mktemp('/tmp/TestDaemon-XXXXX');

	unless (link $file, $new_file) {
		copy $file, $new_file;
	}

	return $new_file;
}

1;

__END__

=head1 NAME

Test::Daemon::Common - Helper common functions

=head1 DESCRIPTION

This module contains functions used by other modules in the framework.

=head1 FUNCTIONS

=head2 load_sub

Return reference to a function, which fully qualified name was specified as an
argument. It automaticaly loads required module.

=head2 load_sub_unless_sub

Same as load_sub method except the case when code reference is passed to it as
an argument. In that case the reference is returned.

=head2 get_file

Creates a hard link to specified file and returns its name. If its not possible
to create the hard link, file is copied instead.

=head1 SEE ALSO

L<Test::Daemon> - Test::Daemon framework documentation index

=head1 AUTHOR

Petr Malat <oss@malat.biz>

=head1 COPYRIGHT

Copyright (c) 2011 - 2012 by Petr Malat E<lt>oss@malat.bizE<gt>

This program is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.
See F<http://www.perl.com/perl/misc/Artistic.html>.
