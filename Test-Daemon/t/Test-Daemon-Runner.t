# Verify, that Test::Daemon::Runner works
use strict;
use Test::More tests => 41;
use IPC::SysV qw(IPC_CREAT IPC_EXCL S_IRUSR S_IWUSR);
use IPC::Msg;
use File::Basename;
use File::Find;
use JSON;
use Data::Dumper;

# Create socket to comunicate with fake tests
$ENV{MSG_KEY} = 12435687;

# Setup variables according to helper files
$ENV{TEST_DAEMON_CONFIG} = dirname(__FILE__) . '/Test-Daemon-Runner.dir/config.js';
my %tests_to_run;
find(sub {$tests_to_run{$File::Find::name} = 1 if /\.pl$/ }, 
		$ENV{PWD} . '/' . dirname(__FILE__) . '/Test-Daemon-Runner.dir/tests/');

# Testing
use_ok('Test::Daemon::Runner');


my $child = fork;
if ($child == 0) {
	sleep 1;
	my $runner = new Test::Daemon::Runner;
	$runner->run();
	exit 0;
} elsif ($child > 0) {
	my $buf;
	my $msg = IPC::Msg->new($ENV{MSG_KEY}, IPC_CREAT | S_IRUSR | S_IWUSR) or die;

	my $receive = sub {
		my $environment = shift;
		my %env_check = @_;
		my $data;

		eval {
			local $SIG{ALRM} = sub { die "ALARM\n" };
			alarm 3;

			# Read message from executed test
			$msg->rcv($buf, 8000, 1) or die;
			$data = from_json($buf);

			alarm 0;
		};

		unless (defined $environment) {
			ok($@ eq "ALARM\n", 'No test was started');
		} else {
			unless ($environment eq '*') {
				ok($data->{file} =~ /\/$environment\/[^\/]*$/, "Test for environment '$environment' was run");
			}

			ok(defined $tests_to_run{$data->{file}}, "Test that $data->{file} is run once");
			delete $tests_to_run{$data->{file}};

			while (my ($k, $v) = each %env_check) {
				is($data->{env}{$k}, $v, "Environment variable '$k' is set to '$v'");
			}
		} 

		return $data;
	};

	my $send = sub {
		my ($data, $rtn) = @_;
		$msg->snd($data->{flag}, to_json({return => $rtn}));
	};

	my $data;
	my $test_rtn = 0;

	my $check_env = sub {
		my $data = shift;
		my ($vars, $vals) = @_;

		foreach my $var (@$vars) {
			my $val = $data->{env}{$var};
			if (defined $val) {
				my $found = grep $_ eq $val, @$vals;
				ok($found >= 1, "Environment variable '$var' is one of the following: " . join ', ', @$vals);
				for (my $i = $#$vals; $i >= 0; $i--) {
					if ($vals->[$i] eq $val) {
						splice @$vals, $i, 1;
						last;
					}
				}
			} else {
				fail("Environment variable '$var' is not defined");
			}
		}
	};

	my $test_env_default = sub {
		my ($data1, $data2, $data3);
		$data1 = $receive->('default');
		$data2 = $receive->('default');
		$data3 = $receive->('default');
		$receive->(undef); # Nothing else should be received

		# Check IDs
		my @running_testcase_ids = (1, 1, 2, 2);
		$check_env->($data,  ['running_testcase_id'], \@running_testcase_ids);
		$check_env->($data1, ['running_testcase_id'], \@running_testcase_ids);
		$check_env->($data2, ['running_testcase_id'], \@running_testcase_ids);
		$check_env->($data3, ['running_testcase_id'], \@running_testcase_ids);

		# Answer one
		$send->($data3, $test_rtn++); 
		push @running_testcase_ids, $data3->{env}{running_testcase_id};

		# Receive
		$data3 = $receive->('default');
		$receive->(undef); # Nothing else should be received
		$check_env->($data3, ['running_testcase_id'], \@running_testcase_ids);

		# Answer all but one
		$send->($data1, $test_rtn++); 
		push @running_testcase_ids, $data1->{env}{running_testcase_id};
		$send->($data2, $test_rtn++); 
		push @running_testcase_ids, $data2->{env}{running_testcase_id};
		$send->($data3, $test_rtn++); 
		push @running_testcase_ids, $data3->{env}{running_testcase_id};

		# Receive
		$data3 = $receive->('default');
		$receive->(undef); # Nothing else should be received
		$check_env->($data3, ['running_testcase_id'], \@running_testcase_ids);

		# Answer remaining
		$send->($data, $test_rtn++); 
		$receive->(undef); # Nothing else should be received
		$send->($data3, $test_rtn++); 
	};

	my $test_env_double = sub {
		$receive->(undef); # Nothing else should be received
		$send->($data, $test_rtn++); 

		$data = $receive->('double', running_testcase_id => 3);
		$check_env->($data, ['second_world_id', 'first_world_id'], [1, 2]);
		$receive->(undef); # Nothing else should be received
		$send->($data, $test_rtn++); 

		$data = $receive->('double', running_testcase_id => 3);
		$check_env->($data, ['second_world_id', 'first_world_id'], [1, 2]);
		$receive->(undef); # Nothing else should be received
		$send->($data, $test_rtn++); 
	};

	# Work in eval, MSQ queue has to be deleted at the end!
	eval {
		$data = $receive->('*');
		if ($data->{file} =~ /default\/[^\/]+$/) {
			$test_env_default->();
			$data = $receive->('double', running_testcase_id => 3);
			$check_env->($data, ['second_world_id', 'first_world_id'], [1, 2]);
			$test_env_double->();
		} else {
			$test_env_double->();
			$data = $receive->('default');
			$test_env_default->();
		}
		$receive->(undef); # Nothing else should be received
	};

	$msg->remove;
} else {
	fail('Fork testing process');
}

exit 0;
