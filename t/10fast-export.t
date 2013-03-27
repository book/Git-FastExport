use strict;
use warnings;
use Test::More;
use Test::Git;

# this script tests the parsing of fast-export block data

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
        footer => "\012",
    },
    {   type   => 'commit',
        header => 'commit refs/heads/before',
        data   => "first commit\n",
        mark   => ['mark :2'],
        author => [
            'author Philippe Bruhat (BooK) <book@cpan.org> 1213115458 +0200'
        ],
        committer => [
            'committer Philippe Bruhat (BooK) <book@cpan.org> 1213115458 +0200'
        ],
        files  => ['M 0100644 :1 loremipsum.txt'],
        date   => 1213115458,
        footer => "\012",
    },
    {   type   => 'blob',
        header => 'blob',
        data   => join( '', @latin[ 0, 1, 2, 3 ] ),
        mark   => ['mark :3'],
        footer => "\012",
    },
    {   type   => 'commit',
        header => 'commit refs/heads/before',
        mark   => ['mark :4'],
        author => [
            'author Philippe Bruhat (BooK) <book@cpan.org> 1213115469 +0200'
        ],
        committer => [
            'committer Philippe Bruhat (BooK) <book@cpan.org> 1213115469 +0200'
        ],
        data   => "second commit\n",
        from   => ['from :2'],
        files  => ['M 0100644 :3 loremipsum.txt'],
        date   => 1213115469,
        footer => "\012",
    },
    {   type   => 'blob',
        header => 'blob',
        data   => join( '', @latin[ 0, 1, 2, 3, 4 ] ),
        mark   => ['mark :5'],
        footer => "\012",
    },
    {   type   => 'progress',
        header => 'progress [] 5 objects',
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
        data   => "another commit on master\n",
        from   => ['from :4'],
        files  => ['M 0100644 :5 loremipsum.txt'],
        date   => 1213115504,
        footer => "\012",
    },
    {   type   => 'blob',
        header => 'blob',
        data   => join( '', @latin[ 0, 2, 3 ] ),
        mark   => ['mark :7'],
        footer => "\012",
    },
    {   type   => 'commit',
        header => 'commit refs/tags/deletion',
        mark   => ['mark :8'],
        author => [
            'author Philippe Bruhat (BooK) <book@cpan.org> 1213115522 +0200'
        ],
        committer => [
            'committer Philippe Bruhat (BooK) <book@cpan.org> 1213115522 +0200'
        ],
        data   => "removed some lines\n",
        from   => ['from :4'],
        files  => ['M 0100644 :7 loremipsum.txt'],
        date   => 1213115522,
        footer => "\012",
    },
    {   type   => 'blob',
        header => 'blob',
        data   => join( '', @latin[ 0, 2, 3, 5 ] ),
        mark   => ['mark :9'],
        footer => "\012",
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
        data   => "added some lines too\n",
        from   => ['from :8'],
        files  => ['M 0100644 :9 loremipsum.txt'],
        date   => 1213115555,
        footer => "\012",
    },
    {   type   => 'progress',
        header => 'progress [] 10 objects',
    },
    {   type   => 'blob',
        header => 'blob',
        data   => join( '', @latin[ 0, 1, 2, 3, 4, 6 ] ),
        mark   => ['mark :11'],
        footer => "\012",
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
        data   => "added some lines on the master\n",
        from   => ['from :6'],
        files  => ['M 0100644 :11 loremipsum.txt'],
        date   => 1213115577,
        footer => "\012",
    },
    {   type   => 'blob',
        header => 'blob',
        data   => join( '', @latin[ 0, 2, 3, 4, 6, 5 ] ),
        mark   => ['mark :13'],
        footer => "\012",
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
        data   => "merged branch into master\n",
        from   => ['from :12'],
        merge  => ['merge :10'],
        files  => ['M 0100644 :13 loremipsum.txt'],
        date   => 1213115620,
        footer => "\012",
    },
    {   type   => 'blob',
        header => 'blob',
        data   => join( '', @latin[ 0, 2, 3, 4, 6, 5, 7 ] ),
        mark   => ['mark :15'],
        footer => "\012",
    },
    {   type   => 'progress',
        header => 'progress [] 15 objects',
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
        data   => "more latin words\n",
        from   => ['from :14'],
        files  => ['M 0100644 :15 loremipsum.txt'],
        date   => 1213115889,
        footer => "\012",
    },
    {   type   => 'reset',
        header => 'reset refs/tags/removal',
        from   => ['from :8'],
        footer => "\012",
    },
);

plan tests => 1 + 3 * @blocks + 2;

use_ok('Git::FastExport');

my $export = Git::FastExport->new( test_repository() );    # unused repository
open my $fh, 't/fast-export' or die "Can't open t/fast-export: $!";

my @strings;
{
    open my $gh, 't/fast-export' or die "Can't open t/fast-export: $!";
    my $string = join '', <$gh>;
    close $gh;
    @strings
        = split
        /(?<=\012\012)|(?<=progress . objects\012)|(?<=progress .. objects\012)/m,
        $string;

    # we actually change the progress markers
    s/progress/progress []/g for @strings;
}

$export->{export_fh} = $fh;

$_ = 'canari';

for my $block (@blocks) {
    my $b = $export->next_block();
    isa_ok( $b, 'Git::FastExport::Block' );
    my $mesg = $block->{mark} ? $block->{mark}[0] : $block->{header};
    chomp $mesg;
    is_deeply( $b, $block, "$mesg object" );
    is( $b->as_string, shift @strings, "$mesg string dump" );
}

is( $export->next_block(), undef, 'no more blocks' );

is( $_, 'canari', 'the canari survived' );

