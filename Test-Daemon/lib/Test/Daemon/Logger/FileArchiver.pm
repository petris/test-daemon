package Test::Daemon::Logger::FileArchiver;
use strict;
use Test::Daemon::Object;
use File::Path qw(make_path);

our @ISA = qw(Test::Daemon::Object);
our @MANDATORY_ARGS = qw(root);
our $VERSION = 0.01;

sub log_info($$$) {
	my ($self, $info, $files) = @_;

	system "cp -r $files/* '$self->{root}'";
	return 0;
}

sub testset_done {
	return 0;
}

__END__

=head1 NAME

Test::Daemon::Logger::FileArchiver - Copy logged files to specified destination

=head1 DESCRIPTION

=head1 METHODS

=head2 new

=head1 SEE ALSO

L<Test::Daemon> - Test::Daemon framework documentation index.

=head1 AUTHOR

Petr Malat <oss@malat.biz>

=head1 COPYRIGHT

Copyright (c) 2011 - 2012 by Petr Malat E<lt>oss@malat.bizE<gt>

This program is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.
See F<http://www.perl.com/perl/misc/Artistic.html>.
