# Verify, that slave deployments are called in parallel

use strict;
use Test::More tests => 2;
use Test::Daemon::Environment;
use Test::MockObject;

my $fd1 = Test::MockObject->new();
$fd1->fake_module('First::Fake::Deployment', new        => sub { bless {}, 'First::Fake::Deployment' }, 
		                             out_prefix => sub { return 'Fake1'; },
		                             deploy     => sub { sleep 3 });

my $fd2 = Test::MockObject->new();
$fd2->fake_module('Second::Fake::Deployment', new        => sub { bless {}, 'Second::Fake::Deployment' }, 
		                              out_prefix => sub { return 'Fake2'; },
		                              deploy     => sub { sleep 5 }, 
					      run        => sub {});

my $deployment = new Test::Daemon::Environment(
	name => 'A Environment',
	resources => {},
	deployments => [
		['First::Fake::Deployment', {}],
		['Second::Fake::Deployment', {}],
	]
);

# deploy
my $time = time;
$deployment->deployments_do([], 'deploy', 10);
my $delay = time - $time;
ok(time - $time >= 5, 'Sleeps at least 5 seconds');
ok(time - $time <= 6, 'Sleeps 6 seconds at maximum');
