# Verify, that DBI logger works
use strict;
use Test::More tests => 14;
use Test::MockObject;

# Fake DBI
my $connection_mock = new Test::MockObject;
$connection_mock->set_true('do');

my $dbi_mock = new Test::MockObject;
$dbi_mock->fake_module('DBI', 'connect' => sub { $dbi_mock->connect(@_[1 .. $#_]) });
$dbi_mock->mock('connect' => sub { return $connection_mock });

# Tests
package main;

use_ok('Test::Daemon::Logger::DBI');

my $db = 'dbi:SQLite:dbname=/srv/test_daemon/results.sqlite';
my $columns = ["Test::Daemon::TestCase::name", "Test::Daemon::start", "Test::Daemon::result"]; 
my $db_logger = new Test::Daemon::Logger::DBI(db => $db, columns => $columns);

$dbi_mock->called_pos_ok(1, 'connect', 'DBI->connect called');
$dbi_mock->called_args_pos_is(1, 2, $db, 'DBI->connect 1. argument is DBI string');
$dbi_mock->called_args_pos_is(1, 3, '', 'DBI->connect 2. argument is empty (default username)');
$dbi_mock->called_args_pos_is(1, 4, '', 'DBI->connect 3. argument is empty (default password)');

my $user = 'A username';
my $pass = 'Some password';
$db_logger = new Test::Daemon::Logger::DBI(db => $db, columns => $columns, 
					   user => $user, password => $pass);

$dbi_mock->called_pos_ok(2, 'connect', 'DBI->connect called');
$dbi_mock->called_args_pos_is(2, 2, $db, 'DBI->connect 1. argument is DBI string');
$dbi_mock->called_args_pos_is(2, 3, $user, 'DBI->connect 2. argument is username');
$dbi_mock->called_args_pos_is(2, 4, $pass, 'DBI->connect 3. argument is password');

my %info = (
	'Test::Daemon::TestCase::name' => 'TDTCname',
	'Test::Daemon::start'   => 'TDs',
	'Test::Daemon::result'  => 'TDr',
	'Test::Daemon::another' => 'TDa'
);
$db_logger->log_info(\%info, '/tmp');

$connection_mock->called_pos_ok(1, 'do', 'Connection method do called');
$connection_mock->called_args_pos_is(1, 2, 
	'INSERT INTO results("Test::Daemon::TestCase::name", "Test::Daemon::start", "Test::Daemon::result") VALUES(?, ?, ?)', 
	'do 1. argument is correct SQL');
$connection_mock->called_args_pos_is(1, 4, $info{'Test::Daemon::TestCase::name'}, 'do 3. argument is value of 1. column');
$connection_mock->called_args_pos_is(1, 5, $info{'Test::Daemon::start'}, 'do 4. argument is value of 2. column');
$connection_mock->called_args_pos_is(1, 6, $info{'Test::Daemon::result'}, 'do 5. argument is value of 3. column');
