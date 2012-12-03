use strict;

use AnyEvent;

use Test::More tests => 4;
use Test::Daemon::Runner;
use Test::Daemon;
use JSON;

my $cv = AE::cv;
my %args = (
	run => [
		testsets => {
			default => {
				root => "tests/",
				run  => [".*\\.pl"],
				get_info => "Test::Daemon::Deployment::Exec::get_info"
			}
		},
		environments => {
			default => {
				provided_resources => {
					env_running_tc_1 => {
						provides => ["running_testcase"],
						variables => {"id" => 1}
					},
					env_running_tc_2 => {
						provides  => ["running_testcase"],
						variables => {"id" => 2}
					}
				},
				exclusive_resources => {
					world => ["world_resource"]
				},
				deployments => [
					["Test::Daemon::Deployment::Exec", { }]
				]
			}
		}
	]
);

my $td = new Test::Daemon(provided_resources => {
		"First_World_Resource" => {
			"provides"  => ["world_resource"],
			"variables" => {"id" => 1}
		},
		"Second_World_Resource" => {
			"provides"  => ["world_resource"],
			"variables" => {"id" => 2}
		}
	}, socket => '127.0.0.1:54327');

{
	no strict 'refs';
	undef *{'Test::Daemon::Runner::run'};
	*{'Test::Daemon::Runner::run'} = sub {
		my $self = shift;

		is_deeply($self->{environments}, $args{run}[3], 
			"Correct environments are passed to Runner");
		is($self->{resources}, $td->{provided_resources},
			"Shared resource pool is used");
	};
}

my @handles;
	
my $h;

$h = new AnyEvent::Handle(connect => ['127.0.0.1', 54327], 
	on_eof   => sub { 
		pass("Connection is closed");
		$cv->send;
	},
	on_error => sub { 
		fail("Connection error");
		$cv->send;
	},
	on_read  => sub {
		$h->push_read(json => sub {
			my ($handle, $msg) = @_;
			is($msg->{ok}{message}, 'Runner scheduled', 'Expected message returned');
		});
	},
	on_connect => sub {
		$h->push_write(to_json(\%args)); 
		$h->push_shutdown();
	});

$cv->recv;
exit 0;
