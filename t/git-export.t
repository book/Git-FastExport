use strict;
use warnings;
use Test::More;
use File::Slurp;

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
    {   type   => 'blob',
        header => 'blob',
        data   => join( '', @latin[ 0, 1, 2 ] ),
        mark   => ['mark :1'],
    },
    {   type   => 'commit',
        header => 'commit refs/heads/master',
        data   => "first commit\n",
        mark   => ['mark :2'],
        author => [
            'author Philippe Bruhat (BooK) <book@cpan.org> 1213115458 +0200'
        ],
        committer => [
            'committer Philippe Bruhat (BooK) <book@cpan.org> 1213115458 +0200'
        ],
        files => ['M 0100644 :1 loremipsum.txt'],
    },
    {   type   => 'blob',
        header => 'blob',
        data   => join( '', @latin[ 0, 1, 2, 3 ] ),
        mark   => ['mark :3'],
    },
    {   type   => 'commit',
        header => 'commit refs/heads/master',
        mark   => ['mark :4'],
        author => [
            'author Philippe Bruhat (BooK) <book@cpan.org> 1213115469 +0200'
        ],
        committer => [
            'committer Philippe Bruhat (BooK) <book@cpan.org> 1213115469 +0200'
        ],
        data  => "second commit\n",
        from  => ['from :2'],
        files => ['M 0100644 :3 loremipsum.txt'],
    },
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

