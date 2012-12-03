# Verify, that Test::Daemon::Runner works
use strict;
use Test::More tests => 9;
use AnyEvent::Handle;
use AnyEvent;
use Data::Dumper;

my @tests = (
	{
		name => "Error message is received, if arguments are not an array",
		request => '{"run": 1}', 
		response => {error => {number => -1, message => 'Message must be in a form { method => [arguments...] }'}}
	}, {
		name => "Error message is received, if the message isn't a hash",
		request => '["run", [1, 2, 3]]', 
		response => {error => {number => -1, message => 'Message must be in a form { method => [arguments...] }'}}
	}, {
		name => "Error message is received, if the message has more elements",
		request => '{"run": [1, 2], "stop": [3, 4]}', 
		response => {error => {number => -1, message => 'Message must be in a form { method => [arguments...] }'}}
	}, {
		name => "Error message is received, if invalid method is called",
		request => '{"not_existing": [1, 2]}', 
		response => {error => {number => -2, message => 'Method not_existing is not supported'}}
	}
	);

use_ok('Test::Daemon');

my $td = new Test::Daemon(provided_resources => {}, socket => '127.0.0.1:54327');
my @handles;
my $cv = AE::cv;
my $counter = 0;
foreach my $test (@tests) {
	my $h;
	
	$h = new AnyEvent::Handle(connect => ['127.0.0.1', 54327], 
		on_eof => sub {
			$h->push_shutdown();
			pass("Connection is closed");
			$cv->send if $counter++ == $#tests;
		},
		on_error => sub { 
			fail("Connection error");
			$cv->send if $counter++ == $#tests;
		},
		on_read => sub {
			$h->push_read(json => sub {
				my ($handle, $msg) = @_;
				is_deeply($msg, $test->{response}, $test->{name});
			});
		},
		on_connect => sub {
			$h->push_write($test->{request}); $h->push_shutdown();
		});
	push @handles, $h;
}

$cv->recv;
exit 0;
