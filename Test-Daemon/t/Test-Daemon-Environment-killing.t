# Verify, that slave deployments are interrupted correctly

use strict;
use Test::More tests => 16;
use Test::MockObject;
use Test::Daemon::Environment;

sub mysleep {
	my ($nf, $tl) = (0, shift);
	($nf, $tl) = select undef, undef, undef, $tl while (defined $tl and $tl > 0);
}

my ($name, $args, $rtn);
my $fd1 = Test::MockObject->new();
$fd1->fake_new('First::Fake::Deployment');
$fd1->mock('cleanup_resources', sub {mysleep 5; return 0});
$fd1->mock('prepare_resources', sub {mysleep 2; return 0});
$fd1->mock('run', sub {mysleep 18; return 42});
$fd1->mock('out_prefix', sub { 'First::Fake::Deployment' });

my $environment = Test::Daemon::Environment->new(
		name => 'A environment',
		resources => {},
		deployments => [['First::Fake::Deployment',  {}]], 
		default_step_timeout => 3, 
		default_run_step_timeout => 16, 
		default_run_step_check_timeout => 5);

foreach my $parallel (0, 5) {
	# interrupt cleanup_resources
	my $time = time;
	$rtn = $environment->deployments_do([], 'cleanup_resources', $parallel);
	ok(time - $time <= 4, 'Cleanup_resources is interrupted');
	ok($rtn == 1, 'One deployment failed');

	# don't interrupt prepare_resources
	$time = time;
	$rtn = $environment->deployments_do([], 'prepare_resources', $parallel);
	ok(time - $time >= 2, 'Prepare_resources is not interrupted');
	ok($rtn == 0, 'None deployment failed');

	# run method is periodically checked and then interrupted
	$time = time;
	$rtn = $environment->deployments_do([], 'run', $parallel, '/some/testcase');
	ok(time - $time <= 17, 'Run is finally interrupted');
	ok($rtn == $Test::Daemon::Environment::KILLED, 'Run was killed');

	# run method is interrupted if running return false
	$fd1->mock('running', sub {
		$fd1->set_false('running');
		return 1;
	});
	$time = time;
	$rtn = $environment->deployments_do([], 'run', $parallel, '/some/testcase');
	ok((time - $time <= 11 and time - $time >= 10), 'Run is finally interrupted');
	ok($rtn == $Test::Daemon::Environment::KILLED, 'Run was killed');
	$fd1->remove('running');
}
