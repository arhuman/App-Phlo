use Test::More;
use App::Phlo;

my $result;

# Copy test dir
`cp -ar t/test_tree/original_tree t/test_tree/copied_tree`;

# Check if copy is equal
$result = `diff -r t/test_tree/original_tree/ t/test_tree/copied_tree/`;
ok(!$result, "Source and copy are identical");

# Compare source and copy size
$result = `du -sh t/test_tree/original_tree/ t/test_tree/copied_tree/`;
is($result, "120K\tt/test_tree/original_tree/\n120K\tt/test_tree/copied_tree/\n","Two directories use the same space");

# phlo the copy
my $phlo = App::Phlo->new({ dryrun => 0, verbose => 0}) or die "Can't instantiate Phlo object ($!)";
$phlo->process({dir => 't/test_tree/copied_tree'});

# Check if copy is still equal
$result = `diff -r t/test_tree/original_tree/ t/test_tree/copied_tree/`;
ok(!$result, "Source and copy are identical");

# Compare source and copy size
$result = `du -sh t/test_tree/original_tree/ t/test_tree/copied_tree/`;
is($result, "120K\tt/test_tree/original_tree/\n104K\tt/test_tree/copied_tree/\n","Copy take less place");

$result = `rm -rf t/test_tree/copied_tree/`;
ok(!$result, 'Copied tree deleted');

done_testing();
