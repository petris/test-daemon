package Test::Daemon::TestSet;
use strict;

use Test::Daemon::Common qw(load_sub_unless_sub);
use Test::Daemon::Object;
use Test::Daemon::TestCase;
use File::Find;

our $VERSION = 0.01;
our @ISA = qw(Test::Daemon::Object);
our @MANDATORY_ARGS = qw(root name);

sub init {
	my $self = shift;
	my %args = @_;

	$self->{root}       = $args{root}; 
	$self->{name}       = $args{name}; 
	$self->{start_hook} = $args{start_hook} || sub {}; 
	$self->{done_hook}  = $args{done_hook}  || sub {}; 
	$self->{loggers}    = $args{loggers}    || []; 
	$self->{envs} = {};
	$self->{tc_infos} = {};

	my $run      = $args{run}      || ['.*']; 
	my $skip     = $args{skip}     || []; 
	my $get_info = $args{get_info} || sub {return {};};

	$get_info = load_sub_unless_sub($get_info);
	$self->{start_hook} = load_sub_unless_sub($self->{start_hook});
	$self->{done_hook}  = load_sub_unless_sub($self->{done_hook});

	find({follow => 1, wanted => sub {
			return unless -f _ || -l _;
			my $name = $File::Find::name;
			$name =~ s|^$args{root}/?||;
			M: { foreach (@$run) { last M if $name =~ /$_/; }; return;}
			foreach (@$skip) { return if $name =~ /$_/; }
			
			my $info = $get_info->($File::Find::name);
			if (ref $info eq 'HASH') {
				$self->add_testcase($File::Find::name, $info);
			} elsif (ref $info eq 'ARRAY') {
				$self->add_testcase($File::Find::name, $_) foreach @$info;
			} else {
				$self->err('CRITICAL', 'get_info() returned unsupported reference');
			}
		}}, $args{root});

	return $self;
}

sub add_testcase($$$) {
	my ($self, $filename, $info) =  @_;
	my $name;

	if (defined $info->{name}) {
		$name = $info->{name};
	} else {
		$name = $filename;
		$name =~ s/$self->{root}//; # Remove root
		$name =~ s/^\/+//;          # Remove first /
		$name =~ s/\/+/::/g;        # Replace / with ::
	}

	$info->{file} = $filename unless defined $info->{file};

	if (defined $self->{tc_infos}{$name}) {
		$self->err('CRITICAL', "Test '$name' defined twice");
	} else {
		my $tc = new Test::Daemon::TestCase(name => $name, info => $info, testset => $self);
		my $env = $tc->get_info('environment');

		$self->{tc_infos}{$name} = $tc;
		push @{$self->{envs}{$env}}, $tc;
	}
}

sub get_environments($) {
	keys %{$_[0]{envs}};
}

sub get_environment_testcases($$) {
	defined $_[0]{envs}->{$_[1]} ? @{$_[0]{envs}->{$_[1]}} : ();
}

sub get_testcases($) {
	map @{$_}, values %{$_[0]{envs}};
}

sub strip_root {
	my $self = shift;
	map {s|$self->{root}/?||; $_} @_;
}

sub loggers {
	@{$_[0]->{loggers}};
}

sub start_hook {
	my $self = shift;

	$self->{start_hook}->($self, @_);
}

sub done_hook {
	my $self = shift;

	$self->{done_hook}->($self, @_);
}

1;

__END__
=head1 NAME

Test::Daemon::TestSet - Manage sets of tests, divide them by environments

=head1 SYNOPSIS

    use Test::Daemon::TestSet;
    
    my $ts = new Test::Daemon::TestSet(
                root    => '/data/tests',
                run     => ['/.*\.pl', '/.*\.sh'], # all perl and shell scripts
                skip    => ['/_[^/]*$'],           # not starting with _
                get_env => sub {
                               open IN, '<', shift;
                               scalar <IN>; <IN> =~ /^#\s*(\w+)/;
                               close IN;
                               return $1;
                           });
    
    print "Found following testcases in the root directory:\n";
    print join "\n", $ts->strip_root($ts->get_testcases()), '';
    
    foreach my $env ($ts->get_environments()) {
        print "Testcases for environment $env\n";
        print join "\n", $ts->get_environment_testcases($env), '';
    }

=head1 USAGE

Test::Daemon::TestSet manages set of testcases and divides them according to
their environment.

=head1 METHODS

=head2 new

New instance constructor with following arguments:

=over 4

=item root

root directory with tests, mandatory

=item run 

array of globs, test must match at least one of these globs to be executed.
By default are files in the root directory are considered.

=item skip 

array of globs, test matching any of these globs is not executed.

=item get_env

function reference or full name of function, which is used to obtain test 
environment. The test filename is passed to it as argument. If the function
is not specified, "default" environment will be used.

=item start_hook

function reference or full name of function, which is executed if start_hook 
method is called. Test::Daemon runs start_hook method before it runs tests.

=item done_hook

function reference or full name of function, which is executed if done_hook 
method is called. Test::Daemon runs done_hook method after it runs tests.

=item loggers

testset specific loggers, returned from loggers method, this value is used by
Test::Daemon.

=back

=head2 get_testcases

Return all testcases in the testset (with full path).

=head2 get_environments

Return all environments in the testset.

=head2 get_environment_testcases

Return all testcases for the environment specified as argument.

=head2 strip_root

Return all arguments with the root path stripped.

=head2 start_hook

Run function from start_hook argument of constructor.

=head2 done_hook

Run function from done_hook argument of constructor.

=head2 loggers

Return loggers - the value passed to constructor as loggers attribute.

=head1 SEE ALSO

L<Test::Daemon::Object> - Base class, allows reading constructor arguments from configuration file.

L<Test::Daemon> - Main Test::Daemon class.

=head1 AUTHOR

Petr Malat E<lt>oss@malat.bizE<gt>

=head1 COPYRIGHT

Copyright (c) 2011 - 2012 by Petr Malat E<lt>oss@malat.bizE<gt>

This program is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.
See F<http://www.perl.com/perl/misc/Artistic.html>.
