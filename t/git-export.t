use strict;
use warnings;
use Test::More;

my @latin = split m!^----\n!m, << 'EOT';
perferendis
sit
praesentium
doloribus
itaque
illum
facere
aliquip
----
harum
rerum
magnam
----
nam
laboriosam
tempora
ullam
odit
quidem
----
blanditiis
nulla
laboriosam
----
vitae
proident
sit
----
officiis
fuga
ipsum
----
beatae
dicta
debitis
----
vitae
repudiandae
laboriosam
EOT

my @blocks = (
    {   type => 'blob',
        data => join( '', @latin[ 0, 1, 2 ] ),
        raw  => [ "blob\n", "mark :1\n", "data 126\n", "\n", ],
        mark => ["mark :1\n"],
    }

);

plan tests => 1 + 2 * @blocks;

use_ok('Git::Export');

my $export = Git::Export->new();
open my $fh, 't/fast-export' or die "Can't open t/fast-export: $!";

$export->{out} = $fh;

for my $block (@blocks) {
    my $b = $export->next_block();
    isa_ok( $b, 'Git::Export::Block' );
    my $mesg = $block->{mark}[0];
    chomp $mesg;
    is_deeply( $b, $block, $mesg );
}

