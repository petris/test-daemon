package Test::Daemon::Object;
use strict;

use Test::Daemon::Common qw(expand_vars);

use Carp qw(croak cluck);
use JSON;

our $config;
our $VERSION = 0.01;

sub new {
	my $ref = shift;
	my $self = bless {}, $ref;

	loadconf() unless defined $config;
	$self->{settings} = $config;
	$self->initialize($ref, @_);

	return $self;
}

sub initialize {
	my $self = shift;
	my $ref = shift or croak("Type must be specified");
	my %args = @_;

	if (defined $config->{$ref}) {
		while (my ($key, $value) = each %{$config->{$ref}}) {
			$args{$key} = $value unless defined $args{$key};
		}
	}

	no strict 'refs';
	if (defined @{$ref . '::MANDATORY_ARGS'}) {
		foreach (@{$ref . '::MANDATORY_ARGS'}) {
			$self->err('CRITICAL', "Mandatory argument '$_' not specified") unless defined $args{$_};
		}
	}

	if (defined $ENV{TEST_DAEMON_DEBUG} and $ENV{TEST_DAEMON_DEBUG} > 2) {
		my $init = join ', ', map "$_=>" . (defined $args{$_} ? $args{$_} : 'undef'), sort keys %args;
		$self->log("Initializing $self as $ref. ARGS: $init");
	}

	if ($ref->can('init')) {
		"$ref\::init"->($self, %args);
	} else {
		$self->copy_args(%args);
	}	
}

sub copy_args {
	my $self = shift;
	my %args = @_;
	$self->{$_} = $args{$_} foreach keys %args;
}

sub loadconf {
	if (defined $ENV{TEST_DAEMON_CONFIG}) {
		my $config_dir;
		if ($ENV{TEST_DAEMON_CONFIG} =~ /^\//) {
			$config_dir = $ENV{TEST_DAEMON_CONFIG};
		} else {
			$config_dir = $ENV{PWD} . '/' . $ENV{TEST_DAEMON_CONFIG};
		}
		$config_dir =~ s/[^\/]*$//;
		$ENV{TEST_DAEMON_CONFIG_DIR} = $config_dir;

		open F, $ENV{TEST_DAEMON_CONFIG} or croak 'Failed to load config file';
		$config = from_json(join '', map expand_vars($_), grep {not /^\s*\/\//} <F>);
		close F;
		if (defined $ENV{TEST_DAEMON_DEBUG} and $ENV{TEST_DAEMON_DEBUG} > 0) {
			Test::Daemon::Object::log(0, 'Loaded config file ', $ENV{TEST_DAEMON_CONFIG});
		}
	} else {
		$config = {};
		if (defined $ENV{TEST_DAEMON_DEBUG} and $ENV{TEST_DAEMON_DEBUG} > 0) {
			Test::Daemon::Object::log(0, 'No config file defined');
		}
	}
}

sub log {
	my $self = shift;
	my $prefix = '';

	if (defined $ENV{TEST_DAEMON_DEBUG}) {
		my @context = caller 1;
		$prefix .= $context[0] . ' ' if $ENV{TEST_DAEMON_DEBUG} > 1;
		$prefix .= $context[3] . ' ' if $ENV{TEST_DAEMON_DEBUG} > 2;
		$prefix .= $context[2] . ' ' if $ENV{TEST_DAEMON_DEBUG} > 3;
		$prefix .= $context[1] . ' ' if $ENV{TEST_DAEMON_DEBUG} > 4;
		print $prefix, @_, "\n" if $ENV{TEST_DAEMON_DEBUG} > 0;
	}
}

sub err {
	my $self = shift;
	if ($_[0] eq 'CRITICAL') {
		local $ENV{TEST_DAEMON_DEBUG} = 99;
		$self->log("Critical error ocurred" . join ' ', @_);
		shift;
	}
	#$Carp::Internal{'Test::Daemon::Object'}++;
	if (defined $ENV{TEST_DAEMON_DEBUG} && $ENV{TEST_DAEMON_DEBUG} > 2) {
		cluck @_;
	} else {
		croak @_;
	}
}

1;
__END__

=head1 NAME

Test::Daemon::Object - Read constructor arguments from file

=head1 SYNOPSIS

Object example:

    package ACME::MachineRiffle;
    use Test::Daemon::Object;

    our @ISA = qw(Test::Daemon::Object);
    our @MANDATORY_ARGS = qw(kill how_much);

    sub init {
        my $self = shift;
	my %args = @_;

	$self->{rounds} = $args{how_much} / ($args{accuracy} || 0.2);
	$self->{blind} = 1 unless $args{kill};
    }

    sub fire {
        my $self = shift;
	my $sound = $self->{blind} ? 'BUM ' : 'BAM ';
	print $sound x $self->{rounds}, "\n";
    }

Configuration file example:

    {
      "ACME::MachineRiffle": {
        "kill": 1,
	"how_much": 3
      }
    }

Usage example:

    use ACME::MachineRiffle;

    my $r1 = new ACME::MachineRiffle();
    my $r2 = new ACME::MachineRiffle(accuracy=>1);
    my $r3 = new ACME::MachineRiffle(accuracy=>0.5, kill=>0);

    $r1->fire;
    #prints BAM BAM BAM BAM BAM BAM BAM BAM BAM BAM BAM BAM BAM BAM BAM

    $r2->fire;
    #prints BAM BAM BAM
    
    $r3->fire;
    #prints BUM BUM BUM BUM BUM BUM


=head1 INTRODUCTION

This class provides a constructor, which check if mandatory arguments are 
present (specified in @MANDATORY_ARGS), reads unspecified arguments from
configuration file, which filename is store in TEST_DAEMON_CONFIG environment 
variable, and then calls init method.

If the init method is not present, it simply copies arguments to the 
"self hash".

=head1 METHODS

=head2 new

Constructor, checks @MANDATORY_ARGS, loads arguments from configuration file
and calls init method with all arguments (both specified in code and loaded
from configuration file).

=head2 initialize

Initialize reference passed as the first argument as the object type passed as 
second argument, but don't call bless. Initialization arguments can be specified 
after object type.

This is used mainly to initialize parrents in the inheritance hiearchy.

=head2 copy_args

Store specified arguments in the "self hash".

=head2 log

Log information.

=head2 err

Report error. If the error is fatal, use 'CRITICAL' as the first argument.

=head1 AUTHOR

Petr Malat E<lt>oss@malat.bizE<gt>

=head1 COPYRIGHT

Copyright (c) 2011 - 2012 by Petr Malat E<lt>oss@malat.bizE<gt>

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
See F<http://www.perl.com/perl/misc/Artistic.html>.
