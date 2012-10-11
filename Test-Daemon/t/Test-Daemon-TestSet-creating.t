use strict;
use Test::More tests => 10;
use List::Util 'shuffle';

our $ROOT      = '/some/fake/path';
our @MATCH_01  = qw(blah/tc_01.py bloh/TC_01.py);
our @MATCH_foo = qw(bar/bar/tc_foo.py);
our @OTHER     = qw(blah/Tc_01.py bloh/aTC_01.py foo/ blah/tc_01.pyc bar/tc_10.py);

use_ok('Test::Daemon::TestSet');

{
	no warnings 'once';
	undef *Test::Daemon::TestSet::find;
	*Test::Daemon::TestSet::find = sub {
		my ($args, $root) = @_;
		ok($args->{follow}, 'follow is enabled');
		ok(defined $args->{wanted}, 'wanted is specified');
		is($root, $ROOT, 'root is correctly set');

		local $File::Find::fullname = '/etc/passwd';
		for my $file (shuffle @MATCH_01, @MATCH_foo, @OTHER) {
			local $File::Find::name = $ROOT . '/' . $file;
			$args->{wanted}->();
		}
	};
}

my $ts = new Test::Daemon::TestSet(
		name     => 'default', 
		root     => $ROOT, 
		run      => ['/tc_.*.py$', '/TC_.*.py$'], 
		skip     => ['/tc_1.*py'], 
		get_info => sub {return {environment => [$_[0] =~ /_(.*)\./]->[0], file => $_[0]}});
is_deeply([sort $ts->get_environments], [sort '01', 'foo'], 'returned environments');
is_deeply([sort map $_->get_info('file'), $ts->get_testcases], 
		[map "$ROOT/$_", sort @MATCH_01, @MATCH_foo], 'returned testcases');
is_deeply([sort map $_->get_info('file'), $ts->get_environment_testcases('01')],  
		[map "$ROOT/$_", sort @MATCH_01], 'returned testcases for environment 1');
is_deeply([sort map $_->get_info('file'), $ts->get_environment_testcases('foo')], 
		[map "$ROOT/$_", sort @MATCH_foo], 'returned testcases for environment 2');
is_deeply([$ts->strip_root(sort map $_->get_info('file'), $ts->get_testcases)], 
		[sort @MATCH_01, @MATCH_foo], 'returned testcases with root stripped');
is_deeply([sort map $_->name(), $ts->get_testcases], 
		[sort map s/\//::/g && $_, @MATCH_01, @MATCH_foo], 'returned testcases names');

exit 0;
