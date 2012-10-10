# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Test-Daemon-Object.t'

#########################

use Test::More tests => 6;
BEGIN { use_ok('Test::Daemon::Object') };

#########################

# Sample object utilizing Test::Daemon::Object
package ACME::MachineRiffle;
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
    $sound x $self->{rounds};
}

# Another sample object utilizing Test::Daemon::Object
package ACME::EnvReader;
our @ISA = qw(Test::Daemon::Object);
our @MANDATORY_ARGS = qw(name value);

sub get_value {
	my $self = shift;
	return $self->{value};
}

sub get_name {
	my $self = shift;
	return $self->{name};
}

# Use sample object
package main;
$ENV{TESTD_CONFIG} = '/tmp/ACME-MachineRiffle-test.js';
open CONF, '>', $ENV{TESTD_CONFIG};
print CONF '{
		"ACME::MachineRiffle": {"kill": 1, "how_much": 3}, 
		"ACME::EnvReader":     {"name": "${}{PATH}", "value": "${PATH}"}
	}', "\n";
close CONF;

my $r1 = new ACME::MachineRiffle();
my $r2 = new ACME::MachineRiffle(accuracy=>1);
my $r3 = new ACME::MachineRiffle(accuracy=>0.5, kill=>0);

is($r1->fire, 'BAM 'x15, 'Basic initialization');
is($r2->fire, 'BAM 'x3,  'Optional argument');
is($r3->fire, 'BUM 'x6,  'Overiding argument');

my $r4 = new ACME::EnvReader();
is($r4->get_name,  '${PATH}',  'Expansion of ${}');
is($r4->get_value, $ENV{PATH}, 'Variable expansion');

#unlink $ENV{TESTD_CONFIG};

