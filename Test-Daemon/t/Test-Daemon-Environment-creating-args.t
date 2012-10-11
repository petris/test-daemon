# Test if arguments are correctly passed to the created deployments

use Test::More tests => 7;
use Test::MockObject;
use Data::Dumper;

my $fd1 = Test::MockObject->new();
my $sub1 = sub {$fd1->log_call('new', @_); bless {}, 'First::Fake::Deployment'};
$fd1->fake_module('First::Fake::Deployment', new => $sub1);
$fd1->mock(new => $sub1);

my $fd2 = Test::MockObject->new();
my $sub2 = sub {$fd2->log_call('new', @_); bless {}, 'Second::Fake::Deployment'};
$fd2->fake_module('Second::Fake::Deployment', new => $sub2, run => sub {});
$fd2->mock(new => $sub2);

my $args1 = { name => 'D1', res => { 'node1.example.com' => [qw(linux name4)] }};
my $args2 = { name => 'D2', res => { 'node2.example.com' => [qw(bash name4)] }, numbers => [1, 2, 3]};
my $args3 = { name => 'D3', res => { 'node1.example.com' => [qw(linux name4)] }};

my $deployments = [
	['First::Fake::Deployment',  $args1],
	['Second::Fake::Deployment', $args2],
	['First::Fake::Deployment',  $args3],
];

use_ok('Test::Daemon::Environment');
my $env_res = { A => [1, 2, 3] };
my $env = Test::Daemon::Environment->new(name => 'A Environment', deployments => $deployments, resources => $env_res); 

$fd1->called_pos_ok(0, 'new', 'Create first First::Fake::Deployment object');
my @args = $fd1->call_args(1);
is_deeply([$args[0], {@args[1 .. $#args]}], 
		['First::Fake::Deployment', {%$args1, deployments => $env->{deployments}, resources => $env_res}], 
		'Correct arguments passed to new #1');

$fd1->called_pos_ok(1, 'new', 'Create second First::Fake::Deployment object');
@args = $fd1->call_args(2);
is_deeply([$args[0], {@args[1 .. $#args]}], 
		['First::Fake::Deployment', {%$args3, deployments => $env->{deployments}, resources => $env_res}], 
		'Correct arguments passed to new #2');

$fd2->called_pos_ok(0, 'new', 'Create first Second::Fake::Deployment object');
@args = $fd2->call_args(1);
is_deeply([$args[0], {@args[1 .. $#args]}], 
		['Second::Fake::Deployment', {%$args2, deployments => $env->{deployments}, resources => $env_res}], 
		'Correct arguments passed to new #3');
