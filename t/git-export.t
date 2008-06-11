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
        date  => 1213115458,
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
        date  => 1213115469,
    },
    {   type   => 'blob',
        header => 'blob',
        data   => join( '', @latin[ 0, 1, 2, 3, 4 ] ),
        mark   => ['mark :5'],
    },
    {   type   => 'commit',
        header => 'commit refs/heads/master',
        mark   => ['mark :6'],
        author => [
            'author Philippe Bruhat (BooK) <book@cpan.org> 1213115504 +0200'
        ],
        committer => [
            'committer Philippe Bruhat (BooK) <book@cpan.org> 1213115504 +0200'
        ],
        data  => "another commit on master\n",
        from  => ['from :4'],
        files => ['M 0100644 :5 loremipsum.txt'],
        date  => 1213115504,
    },
    {   type   => 'blob',
        header => 'blob',
        data   => join( '', @latin[ 0, 2, 3 ] ),
        mark   => ['mark :7'],
    },
    {   type   => 'commit',
        header => 'commit refs/heads/master',
        mark   => ['mark :8'],
        author => [
            'author Philippe Bruhat (BooK) <book@cpan.org> 1213115522 +0200'
        ],
        committer => [
            'committer Philippe Bruhat (BooK) <book@cpan.org> 1213115522 +0200'
        ],
        data  => "removed some lines\n",
        from  => ['from :4'],
        files => ['M 0100644 :7 loremipsum.txt'],
        date  => 1213115522,
    },
    {   type   => 'blob',
        header => 'blob',
        data   => join( '', @latin[ 0, 2, 3, 5 ] ),
        mark   => ['mark :9'],
    },
    {   type   => 'commit',
        header => 'commit refs/heads/master',
        mark   => ['mark :10'],
        author => [
            'author Philippe Bruhat (BooK) <book@cpan.org> 1213115555 +0200'
        ],
        committer => [
            'committer Philippe Bruhat (BooK) <book@cpan.org> 1213115555 +0200'
        ],
        data  => "added some lines too\n",
        from  => ['from :8'],
        files => ['M 0100644 :9 loremipsum.txt'],
        date  => 1213115555,
    },
    {   type   => 'blob',
        header => 'blob',
        data   => join( '', @latin[ 0, 1, 2, 3, 4, 6 ] ),
        mark   => ['mark :11'],
    },
    {   type   => 'commit',
        header => 'commit refs/heads/master',
        mark   => ['mark :12'],
        author => [
            'author Philippe Bruhat (BooK) <book@cpan.org> 1213115577 +0200'
        ],
        committer => [
            'committer Philippe Bruhat (BooK) <book@cpan.org> 1213115577 +0200'
        ],
        data  => "added some lines on the master\n",
        from  => ['from :6'],
        files => ['M 0100644 :11 loremipsum.txt'],
        date  => 1213115577,
    },
    {   type   => 'blob',
        header => 'blob',
        data   => join( '', @latin[ 0, 2, 3, 4, 6, 5 ] ),
        mark   => ['mark :13'],
    },
    {   type   => 'commit',
        header => 'commit refs/heads/master',
        mark   => ['mark :14'],
        author => [
            'author Philippe Bruhat (BooK) <book@cpan.org> 1213115620 +0200'
        ],
        committer => [
            'committer Philippe Bruhat (BooK) <book@cpan.org> 1213115620 +0200'
        ],
        data  => "merged branch into master\n",
        from  => ['from :12'],
        merge => ['merge :10'],
        files => ['M 0100644 :13 loremipsum.txt'],
        date  => 1213115620,
    },
    {   type   => 'blob',
        header => 'blob',
        data   => join( '', @latin[ 0, 2, 3, 4, 6, 5, 7 ] ),
        mark   => ['mark :15'],
    },
    {   type   => 'commit',
        header => 'commit refs/heads/master',
        mark   => ['mark :16'],
        author => [
            'author Philippe Bruhat (BooK) <book@cpan.org> 1213115889 +0200'
        ],
        committer => [
            'committer Philippe Bruhat (BooK) <book@cpan.org> 1213115889 +0200'
        ],
        data  => "more latin words\n",
        from  => ['from :14'],
        files => ['M 0100644 :15 loremipsum.txt'],
        date  => 1213115889,
    },
);

plan tests => 1 + 3 * @blocks + 1;

use_ok('Git::Export');

my $export = Git::Export->new();
open my $fh, 't/fast-export' or die "Can't open t/fast-export: $!";
my @strings;
{
    open my $gh, 't/fast-export' or die "Can't open t/fast-export: $!";
    my $string = join '', <$gh>;
    close $gh;
    @strings = split /(?<=\012\012)/m, $string;
}

$export->{out} = $fh;

for my $block (@blocks) {
    my $b = $export->next_block();
    isa_ok( $b, 'Git::Export::Block' );
    my $mesg = $block->{mark}[0];
    chomp $mesg;
    is_deeply( $b, $block, "$mesg object" );
    is( $b->as_string, shift @strings, "$mesg string dump" );
}

is( $export->next_block(), undef, 'no more blocks' );

