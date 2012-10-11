use strict;
use Test::More tests => 16;
use Data::Dumper;

use_ok('Test::Daemon::ResourcePool'); 

my $pool = Test::Daemon::ResourcePool->new(resources => {
            A => { provides => ['A1', 'A2', 'X'], variables => { type => 'TypeA' } },
            B => { provides => ['B1', 'X'], variables => { type => 'TypeB' } },
            C => { provides => ['C1'] }});

# Allocate resource providing A1 exclusivelly
my $resources1 = $pool->try_get_resources({res1 => ['A1']}, {});
is($resources1->{res1}{name}, 'A', 'Resource A is exclusivelly allocated');
is(scalar keys %$resources1, 1, 'No other resource is allocated');
is($resources1->{res1}->get_var('type'), 'TypeA', 'Verify resource variable');

# Try to allocate resource providing A2 and B1 exclusively
my $resources2 = $pool->try_get_resources({res1 => ['A2'], res2 => ['B1']}, {});
is($resources2, undef, 'Resource A is not available for exclusive allocation');

# Try to allocate resource providing A2 and B1 in shared mode
$resources2 = $pool->try_get_resources({}, {res1 => ['A2'], res2 => ['B1']});
is($resources2, undef, 'Resource A is not available for shared allocation');

# Try to allocate two resources provided by B in exclusive and shared mode
$resources2 = $pool->try_get_resources({res1 => ['X']}, {res2 => ['B1']});
is($resources2, undef, 'Resource B can\'t be allocated twice, if one allocation is exclusive');

# Try to allocate two resources provided by B in shared mode
$resources2 = $pool->try_get_resources({}, {res1 => ['X'], res2 => ['B1']});
ok($resources2->{res1}{name} eq 'B' && $resources2->{res1} == $resources2->{res2}, 'Resource B can be allocated twice, if both allocations are shared');
is(scalar keys %$resources2, 2, 'No other resource is allocated');

# Try to allocate four resources provided by C in shared mode
my $resources3 = $pool->try_get_resources({}, {res1 => ['C1'], res2 => ['C1'], res3 => ['C1'], res4 => ['C1']});
ok($resources3->{res1}{name} eq 'C' &&
   $resources3->{res1} == $resources3->{res2} &&
   $resources3->{res2} == $resources3->{res3} &&
   $resources3->{res3} == $resources3->{res4}, 'Resource C can be allocated four times in shared mode');
is(scalar keys %$resources3, 4, 'No other resource is allocated');

# Try to allocate resource provided by C in exclusive mode
my $resources4 = $pool->try_get_resources({res1 => ['C1']}, {});
is($resources4, undef, 'Resource C is not available for exclusive allocation');

# Try to allocate resource provided by C in exclusive mode two times
eval {
my $resources4 = $pool->try_get_resources({res1 => ['C1'], res2 => ['C1']}, {});
};
like($@, qr/^Unable to fullfill resource requirements/, 
		'Resource C is never available for exclusive allocation two times');

# Free resources
$pool->free_resources($resources3);
$pool->free_resources($resources2);
$pool->free_resources($resources1);

# More complicated allocation
$resources1 = $pool->try_get_resources({res1 => ['X']}, {res2 => ['A1', 'A2']});
is($resources1->{res1}{name}, 'B', 'Resource B is allocated to provide X');
is($resources1->{res2}{name}, 'A', 'Resource A is allocated to provide A1 and A2');
is(scalar keys %$resources1, 2, 'No other resource is allocated');
