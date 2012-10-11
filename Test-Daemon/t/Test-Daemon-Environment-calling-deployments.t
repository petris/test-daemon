# Verify, that slave deployments are called correctly 
# and that their return value is correctly handled

use strict;
use Test::More tests => 26;
use Test::MockObject;
use Test::Resub qw(resub);
use Test::Daemon::Environment;

package Test::MockObject2;
our @ISA = qw(Test::MockObject);

package main;
my ($name, $args);
my $fd1 = Test::MockObject->new();
$fd1->fake_new('First::Fake::Deployment');
$fd1->mock('cleanup_resources');
$fd1->mock('deploy');
$fd1->mock('pre_run');
$fd1->mock('run', sub {return 42});
$fd1->mock('collect_info', sub {return first=>1, second=>[2, 3]});
$fd1->mock('out_prefix', sub {return 'First::Fake::Deployment'});

my $fd2 = Test::MockObject2->new();
$fd2->fake_new('Second::Fake::Deployment');
$fd2->mock('prepare_resources');
$fd2->mock('deploy');
$fd2->mock('collect_info', sub {return third=>'Hi!'});
$fd2->mock('post_run');
$fd1->mock('out_prefix', sub {return 'Second::Fake::Deployment'});

my $deployment = Test::Daemon::Environment->new(
	name => 'My Environment',
	resources => {},
	deployments => [
		['First::Fake::Deployment',  {}],
		['Second::Fake::Deployment', {}],
	]);

$fd1->clear(); $fd2->clear();

# cleanup_resources
$deployment->deployments_do([], 'cleanup_resources', 0);
($name, $args) = $fd1->next_call();
is($name, 'cleanup_resources', 'cleanup_resources called on First::Fake::Deployment');
is_deeply($args, [$fd1], 'cleanup_resources called with correct argument');
($name, $args) = $fd2->next_call();
is($name, undef, 'cleanup_resources not called on Second::Fake::Deployment');

# prepare_resources
$deployment->deployments_do([], 'prepare_resources', 0);
($name, $args) = $fd1->next_call();
is($name, undef, 'prepare_resources not called on First::Fake::Deployment');
($name, $args) = $fd2->next_call();
is($name, 'prepare_resources', 'prepare_resources called on Second::Fake::Deployment');
is_deeply($args, [$fd2], 'prepare_resources called with correct argument');

# deploy
$deployment->deployments_do([], 'deploy', 0);
($name, $args) = $fd1->next_call();
is($name, 'deploy', 'deploy called on First::Fake::Deployment');
is_deeply($args, [$fd1], 'deploy called with correct argument');
($name, $args) = $fd2->next_call();
is($name, 'deploy', 'deploy called on Second::Fake::Deployment');
is_deeply($args, [$fd2], 'deploy called with correct argument');

# pre_run
my $test = '/some/test/file';
$deployment->deployments_do([], 'pre_run', 0, $test);
($name, $args) = $fd1->next_call();
is($name, 'pre_run', 'pre_run called on First::Fake::Deployment');
is_deeply($args, [$fd1, $test], 'pre_run called with correct argument');
($name, $args) = $fd2->next_call();
is($name, undef, 'pre_run not called on Second::Fake::Deployment');

# run
my $rc = $deployment->deployments_do([], 'run', 0, $test);
($name, $args) = $fd1->next_call();
is($name, 'run', 'run called on First::Fake::Deployment');
is_deeply($args, [$fd1, $test], 'run called with correct argument');
($name, $args) = $fd2->next_call();
is($name, undef, 'run not called on Second::Fake::Deployment');
is($rc, 42, 'Expected return value returned from run method');

# collect_info
my $dir = '/some/dir';
my $rs = resub 'Test::Daemon::Environment::make_path', sub {
	is_deeply([sort @_], [sort "$dir/Test/MockObject", "$dir/Test/MockObject2"], 'Create directories for collect_info');
};
my %info = $deployment->collect_info($test, $rc, $dir);
($name, $args) = $fd1->next_call();
is($name, 'collect_info', 'collect_info called on First::Fake::Deployment');
is_deeply($args, [$fd1, $test, $rc, "$dir/Test/MockObject"], 'collect_info called with correct argument');
($name, $args) = $fd2->next_call();
is($name, 'collect_info', 'collect_info called on Second::Fake::Deployment');
is_deeply($args, [$fd2, $test, $rc, "$dir/Test/MockObject2"], 'collect_info called with correct argument');
is_deeply(\%info, {'Test::MockObject::first' => 1, 'Test::MockObject::second' => [2, 3], 
		   'Test::MockObject2::third' => 'Hi!'}, 'collect_info return value');

# post_run
$deployment->deployments_do([], 'post_run', 0, $test, $rc);
($name, $args) = $fd1->next_call();
is($name, undef, 'post_run not called on First::Fake::Deployment');
($name, $args) = $fd2->next_call();
is($name, 'post_run', 'post_run called on Second::Fake::Deployment');
is_deeply($args, [$fd2, $test, $rc], 'post_run called with correct argument');
