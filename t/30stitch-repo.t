use strict;
use warnings;
use Test::More;
use File::Path;
use t::Utils;
use Git::FastExport::Stitch;
use Test::Git;

# first, make sure we have the right git version
has_git('1.5.4');

my @tests = (

    # source repositories, refs, expected repository x @algo, todo x @algo
    # linear trees
    # 0 - 3
    [ 'A1 A2-A1 A3-A2', 'master=A3', 'A1 A2-A1 A3-A2', 'A1 A2-A1 A3-A2',  'A1 A2-A1 A3-A2', 'A1 A2-A1 A3-A2',],
    [   'A1 A2-A1 A3-A2 B1 B2-B1 B3-B2',
        'master=A3 master=B3 tag>A2',
        'A1 A2-A1 A3-A2 B1-A3 B2-B1 B3-B2',
        'A1 A2-A1 A3-A2 B1-A3 B2-B1 B3-B2',
        'A1 A2-A1 A3-A2 B1-A3 B2-B1 B3-B2',
        'A1 A2-A1 A3-A2 B1-A3 B2-B1 B3-B2',

    ],
    [   'A1 B1 A2-A1 B2-B1 A3-A2 B3-B2',
        'master=A3 master=B3 tag:msg>A2',
        'A1 B1-A1 A2-B1 B2-A2 A3-B2 B3-A3',
        'A1 B1-A1 A2-B1 B2-A2 A3-B2 B3-A3',
        'A1 B1-A1 A2-B1 B2-A2 A3-B2 B3-A3',
        'A1 B1-A1 A2-B1 B2-A2 A3-B2 B3-A3',

    ],

    [   'A1+ B1 A2-A1 B2-B1 A3-A2 B3-B2',
        'master=A3 master=B3 tag:msg>A2',
        'B1 A1+-B1 A2-A1+ B2-A2 A3-B2 B3-A3',
        'B1 A1+-B1 A2-A1+ B2-A2 A3-B2 B3-A3',
        'A1+ B1-A1+ A2-B1 B2-A2 A3-B2 B3-A3',
        'A1+ B1-A1+ A2-B1 B2-A2 A3-B2 B3-A3',

    ],

    [   'A1 B1 C1 A2-A1 B2-B1 C2-C1 A3-A2 B3-B2 C3-C2',
        'master=A3 master=B3 master=C3',
        'A1 B1-A1 C1-B1 A2-C1 B2-A2 C2-B2 A3-C2 B3-A3 C3-B3',
        'A1 B1-A1 C1-B1 A2-C1 B2-A2 C2-B2 A3-C2 B3-A3 C3-B3',
        'A1 B1-A1 C1-B1 A2-C1 B2-A2 C2-B2 A3-C2 B3-A3 C3-B3',
        'A1 B1-A1 C1-B1 A2-C1 B2-A2 C2-B2 A3-C2 B3-A3 C3-B3',

    ],

    # simple diamonds
    # 4 - 8
    [   'A1 A2-A1 A3-A1 A4-A2A3',
        'master=A4',
        'A1 A2-A1 A3-A1 A4-A2A3',
        'A1 A2-A1 A3-A1 A4-A2A3',
        'A1 A2-A1 A3-A1 A4-A2A3',
        'A1 A2-A1 A3-A1 A4-A2A3',

    ],
    [   'A1 A2-A1 A3-A1 A4-A2A3 B1 B2-B1 B3-B1 B4-B2B3',
        'master=A4 master=B4 v1>B1 v1>A1',
        'A1 A2-A1 A3-A1 A4-A2A3 B1-A4 B2-B1 B3-B1 B4-B2B3',
        'A1 A2-A1 A3-A1 A4-A2A3 B1-A4 B2-B1 B3-B1 B4-B2B3',
        'A1 A2-A1 A3-A1 A4-A2A3 B1-A4 B2-B1 B3-B1 B4-B2B3',
        'A1 A2-A1 A3-A1 A4-A2A3 B1-A4 B2-B1 B3-B1 B4-B2B3',

    ],
    [   'A1 B1 A2-A1 A3-A1 B2-B1 B3-B1 A4-A2A3 B4-B2B3',
        'master=A4 master=B4',
        'A1 B1-A1 A2-B1 A3-B1 B2-A3 B3-A3 A4-A2B3 B4-B2A4',
        'A1 B1-A1 A2-B1 A3-B1 B2-A2 B3-A2 A4-B2A3 B4-A4B3',
        'A1 B1-A1 A2-B1 A3-B1 B2-A3 B3-A3 A4-A2B3 B4-B2A4',
        'A1 B1-A1 A2-B1 A3-B1 B2-A2 B3-A2 A4-B2A3 B4-A4B3',

    ],
    [   'A1 B1 A2-A1 B2-B1 A3-A1 B3-B1 A4-A2A3 B4-B2B3',
        'master=A4 master=B4 v1:msg1>A2 v2:msg2>B3 v1>B2',
        'A1 B1-A1 A2-B1 B2-A2 A3-B1 B3-A2 A4-B3A3 B4-B2A4',
        'A1 B1-A1 A2-B1 B2-A2 A3-B1 B3-A2 A4-B2A3 B4-A4B3',
        'A1 B1-A1 A2-B1 B2-A2 A3-B1 B3-A2 A4-B3A3 B4-B2A4',
        'A1 B1-A1 A2-B1 B2-A2 A3-B1 B3-A2 A4-B2A3 B4-A4B3',


    ],
    [   'A1 B1 A2-A1 A3-A1 B2-B1 B3-B1 B4-B2B3 A4-A2A3 B5-B4 A5-A4',
        'master=A5 master=B5',
        'A1 B1-A1 A2-B1 A3-B1 B2-A3 B3-A3 B4-B2B3 A4-A2B4 B5-A4 A5-B5',
        'A1 B1-A1 A2-B1 A3-B1 B2-A2 B3-A2 B4-B2B3 A4-B4A3 B5-A4 A5-B5',
        'A1 B1-A1 A2-B1 A3-B1 B2-A3 B3-A3 B4-B2B3 A4-A2B4 B5-A4 A5-B5',
        'A1 B1-A1 A2-B1 A3-B1 B2-A2 B3-A2 B4-B2B3 A4-B4A3 B5-A4 A5-B5',

    ],

    # other trees
    # 9 - 10
    [   'A1 B1 A2-A1 B2-B1 A3-A2 A4-A2 B3-B2 B4-B2 A5-A4A3 B5-B3 B6-B4 B7-B6B5 B8-B7 A6-A5',
        'master=A6 master=B8 topic=A3 topic=B5',
        'A1 B1-A1 A2-B1 B2-A2 A3-B2 A4-B2 B3-A4 B4-A4 A5-B4A3 B5-B3 B6-A5 B7-B6B5 B8-B7 A6-B8',
        'A1 B1-A1 A2-B1 B2-A2 A3-B2 A4-B2 B3-A3 B4-A3 A5-A4B3 B5-A5 B6-B4 B7-B6B5 B8-B7 A6-B8',
        'A1 B1-A1 A2-B1 B2-A2 A3-B2 A4-B2 B3-A4 B4-A4 A5-B4A3 B5-B3 B6-A5 B7-B6B5 B8-B7 A6-B8',
        'A1 B1-A1 A2-B1 B2-A2 A3-B2 A4-B2 B3-A3 B4-A3 A5-A4B3 B5-A5 B6-B4 B7-B6B5 B8-B7 A6-B8',

    ],
    [   'A1 B1 A2-A1 B2-B1 A3-A2 A4-A2 B3-B2 B4-B2 A5-A4A3 B5-B3 B6-B4 B7-B6B5 B8-B7 A6-A5 A7-A3 A8-A6',
        'master=A8 master=B8 topic=A7 topic=B5',
        'A1 B1-A1 A2-B1 B2-A2 A3-B2 A4-B2 B3-A4 B4-A4 A5-B4A3 B5-B3 B6-A5 B7-B6B5 B8-B7 A6-B8 A7-A3 A8-A6',
        'A1 B1-A1 A2-B1 B2-A2 A3-B2 A4-B2 B3-A3 B4-A3 A5-A4B3 B5-A5 B6-B4 B7-B6B5 B8-B7 A6-B8 A7-B3 A8-A6',
        'A1 B1-A1 A2-B1 B2-A2 A3-B2 A4-B2 B3-A4 B4-A4 A5-B4A3 B5-B3 B6-A5 B7-B6B5 B8-B7 A6-B8 A7-A3 A8-A6',
        'A1 B1-A1 A2-B1 B2-A2 A3-B2 A4-B2 B3-A3 B4-A3 A5-A4B3 B5-A5 B6-B4 B7-B6B5 B8-B7 A6-B8 A7-B3 A8-A6',

    ],

    # specially crafted examples
    # 11 - 12
    [   'A1 B2 A3-A1 A4-A1 B5-B2 A6-A1 B7-B2',
        'master=A6 branch1=A3 branch2=A4 master=B5 branch1=B7',
        'A1 B2-A1 A3-B2 A4-B2 B5-A4 A6-B2 B7-A4',
        'A1 B2-A1 A3-B2 A4-B2 B5-A3 A6-B2 B7-A3',
        'A1 B2-A1 A3-B2 A4-B2 B5-A4 A6-B2 B7-A4',
        'A1 B2-A1 A3-B2 A4-B2 B5-A3 A6-B2 B7-A3',

    ],
    [   'A1 B1 C1 A2-A1 B2-B1 C2-C1 A3-A1 B3-B1 C3-C1 A4-A2A3 B4-B2B3 C4-C2C3',
        'master=A4 master=B4 master=C4',
        'A1 B1-A1 C1-B1 A2-C1 B2-A2 C2-B2 A3-C1 B3-A2 C3-B2 A4-B3A3 B4-C3A4 C4-C2B4',
        'A1 B1-A1 C1-B1 A2-C1 B2-A2 C2-B2 A3-C1 B3-A2 C3-B2 A4-C2A3 B4-A4B3 C4-B4C3',
        'A1 B1-A1 C1-B1 A2-C1 B2-A2 C2-B2 A3-C1 B3-A2 C3-B2 A4-B3A3 B4-C3A4 C4-C2B4',
        'A1 B1-A1 C1-B1 A2-C1 B2-A2 C2-B2 A3-C1 B3-A2 C3-B2 A4-C2A3 B4-A4B3 C4-B4C3',

    ],

    # 3-way merges
    # 13-14
    [   'A1 A2-A1 A3-A1 A4-A1 A5-A4A3A2',
        'master=A5',
        'A1 A2-A1 A3-A1 A4-A1 A5-A4A3A2',
        'A1 A2-A1 A3-A1 A4-A1 A5-A4A3A2',
        'A1 A2-A1 A3-A1 A4-A1 A5-A4A3A2',
        'A1 A2-A1 A3-A1 A4-A1 A5-A4A3A2',

    ],
    [   'A1 B1 A2-A1 A3-A1 B2-B1 A4-A1 B3-B1 A5-A4A3A2 B4-B2B3',
        'master=A5 master=B4',
        'A1 B1-A1 A2-B1 A3-B1 B2-A3 A4-B1 B3-A3 A5-A4B3A2 B4-B2A5',
        'A1 B1-A1 A2-B1 A3-B1 B2-A2 A4-B1 B3-A2 A5-A4A3B2 B4-A5B3',
        'A1 B1-A1 A2-B1 A3-B1 B2-A3 A4-B1 B3-A3 A5-A4B3A2 B4-B2A5',
        'A1 B1-A1 A2-B1 A3-B1 B2-A2 A4-B1 B3-A2 A5-A4A3B2 B4-A5B3',
    ],
);

# algorithms to test
my @algo = ( 
    { select => 'last'  , datetype => 'commit_date' },
    { select => 'first' , datetype => 'commit_date' },
    { select => 'last'  , datetype => 'authored_date' } ,
    { select => 'first' , datetype => 'authored_date' } 
);

# useful hack for quick testing
my @nums = 0 .. @tests - 1;
@nums = grep { $_ < @tests } @ARGV if @ARGV;

plan skip_all => 'No test selected' if !@nums;
plan tests => @nums * @algo * 2;

# a counter
my $j = 0;

for my $n (@nums) {
    my ( $src, $refs, @todo ) = @{ $tests[$n] };
    my @dst = splice @todo, 0, scalar @algo;

    # a temporary directory for our tests
    my $dir = File::Spec->rel2abs( File::Spec->catdir( 'git-test', $n ) );
    rmtree( [$dir] );

    # create the source repositories
    my @src = create_repos( $dir => $src, $refs );

    # compute the expected result refs
    my $expected_refs;
    {
        my @refs;
        for my $ref ( split / /, $refs ) {
            my ( $name, $type, $desc ) = split /([>=])/, $ref;
            my ($orig) = $desc =~ /^([A-Z]+)/;
            ( $name, my $msg ) = split /:/, $name;    # annotated tag?
            push @refs, $msg
                ? "$name-$orig:$msg$type$desc"
                : "$name-$orig$type$desc";
        }
        $expected_refs = join ' ', sort @refs;
    }

    # test the 'last' and 'first' algorithms
    for my $i ( 0 .. $#algo ) {

        # create the destination repository
        my $repo = new_repo( $dir => "RESULT-$algo[$i]" );

        # run the stitch algorithm on the source repositories
        my $export = Git::FastExport::Stitch->new(  $algo[$i]  );

        # try all possible parameters to stitch()
        for my $src (@src) {
            my $r;
            if ( $j == 0 ) {
                $r = $src->work_tree;    # a string
            }
            elsif ( $j == 1 ) {
                $r = $src;               # a Git object
            }
            elsif ( $j == 2 ) {
                $r = Git::FastExport->new($src);    # a Git::FastExport
            }
            elsif ( $j == 3 ) {
                $r = Git::FastExport->new($src);             # an initialized
                $r->fast_export(qw( --all --date-order ));   # Git::FastExport
            }
            $export->stitch($r);
            $j = ++$j % 4;
        }

        # run git-fast-import on the destination repository
        my $cmd = $repo->command( 'fast-import', '--quiet' );
        my $fh = $cmd->{stdin};

        # pipe the output of git-stitch-repo into git-fast-import
        while ( my $block = $export->next_block() ) {
            next if $block->{type} eq 'progress';    # ignore progress info
            print {$fh} $block->as_string();
        }
        $cmd->close();

        # get the description of the resulting repository
        my ( $result, $result_refs ) = repo_description($repo);
        if ( $todo[$i] ) {
        TODO: {
                local $TODO = $todo[$i];
                is( $result, $dst[$i], "$src => $dst[$i] ($algo[$i])" );
                is( $result_refs, $expected_refs, "$expected_refs" );
            }
        }
        else {
            is( $result, $dst[$i], "$src => $dst[$i] ($algo[$i])" );
            is( $result_refs, $expected_refs, "$expected_refs" );
        }
    }
}

