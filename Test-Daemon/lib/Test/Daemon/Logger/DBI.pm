package Test::Daemon::Logger::DBI;
use strict;

use Test::Daemon::Object;
use DBI;

our @ISA = qw(Test::Daemon::Object);
our @MANDATORY_ARGS = qw(db columns);
our $VERSION = 0.01;

sub init {
	my $self = shift;
	my %args = @_;

	$args{user} = '' unless defined $args{user};
	$args{password} = '' unless defined $args{password};

	$self->{table} = $args{table} || 'results';
	$self->{columns} = $args{columns};
	$self->{db} = DBI->connect($args{db}, $args{user}, $args{password}, {AutoCommit=>1, PrintError=>1}) or die;
}

sub log_info($$$) {
	my ($self, $info, $files) = @_;
	
	if (defined $self->{columns}) {
		my (@k, @v);

		foreach my $col (@{$self->{columns}}) {
			if (defined $info->{$col}) {
				push @k, $col;
				push @v, $info->{$col};
			} else {
				$self->log('Column ' . $col . ' is nor present in info.');
			}
		}

		my $keys = join '", "', @k;
		my $q = join ', ', map '?', @k;
		$self->{db}->do("INSERT INTO $self->{table}(\"$keys\") VALUES($q)", {}, @v) or $self->err('CRITICAL', $self->{db}->errstr);
	} 
}

1;

__END__

=head1 NAME

Test::Daemon::Logger::DBI - Store results into database using DBI

=head1 SYNOPSIS

Example configuration file segment:

   //   ...
   "loggers": [
      //   ...
      ["Test::Daemon::Logger::DBI",
         {"db": "dbi:SQLite:dbname=/srv/test_daemon/results.sqlite",
          "columns": ["Test::Daemon::name", "Test::Daemon::start", "Test::Daemon::result"]} 
      ],
      //   ...
   ],
   //   ...

=head1 INTRODUCTION

Test::Daemon::Logger::DBI stores test result and collected info into any
database supported by perl DBI module.

=head1 METHODS

=head2 new

New instance constructor with following arguments:

=over 4

=item db (mandatory)

Specifies database, same format as first argument of DBI::connect.

=item user (optional, default '')

User name used to log in to database.

=item password (optional, default '')

Password used to log in to database.

=item columns (mandatory)

Arrays with names of info attributes, which are logged into database.
Attribute name must match a column name in database.

=item table (optional, default 'results')

Database table into which the information are stored

=back

=head2 log_info

Executed by Test::Daemon::Runner after every run testcase.

=head1 SEE ALSO

=over 

=item Test::Daemon::Object

Base class, allows reading constructor arguments from configuration file.

=item Test::Daemon::Runner

Executes method of this objects,

=item DBI

Module used for database access.

=back

=head1 AUTHOR

Petr Malat <oss@malat.biz>
