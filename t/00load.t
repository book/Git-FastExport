use Test::More;

my @modules = qw(
    Git::FastExport
);

plan tests => scalar @modules;

use_ok($_) for sort @modules;

