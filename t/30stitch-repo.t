use strict;
use warnings;
use Test::More;
use File::Temp qw( tempdir );
use IPC::Open2;
use t::Utils;

my @tests = (

    # source repositories, refs, expected repository
    # linear trees
    [ 'A1 A2-A1 A3-A2', 'master=A3', 'A1 A2-A1 A3-A2' ],
    [   'A1 A2-A1 A3-A2 B1 B2-B1 B3-B2',
        'master=A3 master=B3',
        'A1 A2-A1 A3-A2 B1-A3 B2-B1 B3-B2'
    ],
    [   'A1 B1 A2-A1 B2-B1 A3-A2 B3-B2',
        'master=A3 master=B3',
        'A1 B1-A1 A2-B1 B2-A2 A3-B2 B3-A3'
    ],
    [   'A1 B1 C1 A2-A1 B2-B1 C2-C1 A3-A2 B3-B2 C3-C2',
        'master=A3 master=B3 master=C3',
        'A1 B1-A1 C1-B1 A2-C1 B2-A2 C2-B2 A3-C2 B3-A3 C3-B3'
    ],

    # simple diamonds
    [ 'A1 A2-A1 A3-A1 A4-A2A3', 'master=A4', 'A1 A2-A1 A3-A1 A4-A2A3' ],
    [   'A1 A2-A1 A3-A1 A4-A2A3 B1 B2-B1 B3-B1 B4-B2B3',
        'master=A4 master=B4',
        'A1 A2-A1 A3-A1 A4-A2A3 B1-A4 B2-B1 B3-B1 B4-B2B3'
    ],
    [   'A1 B1 A2-A1 A3-A1 B2-B1 B3-B1 A4-A2A3 B4-B2B3',
        'master=A4 master=B4',
        'A1 B1-A1 A2-B1 B2-B1 A3-B2 B3-A2 A4-B3A3 B3-A4',
        'The two master branches should be the same'
    ],
    [   'A1 B1 A2-A1 B2-B1 A3-A1 B3-B1 A4-A2A3 B4-B2B3',
        'master=A4 master=B4',
        'A1 B1-A1 A2-B1 B2-B1 A3-B2 B3-A2 A4-B3A3 B3-A4',
        'The two master branches should be the same'
    ],
    [   'A1 B1 A2-A1 A3-A1 B2-B1 B3-B1 B4-B2B3 A4-A2A3 B5-B4 A5-A4',
        'master=A5 master=B5',
        'A1 B1-A1 A2-B1 B2-B1 A3-B2 B3-A2 B4-B3B2 B3-A4',
        'The two master branches should be the same'
    ],

    # other trees
    [   'A1 B1 A2-A1 B2-B1 A3-A2 A4-A2 B3-B2 B4-B2 A5-A4A3 B5-B3 B6-B4 B7-B6B5 B8-B7 A6-A5 A7-A3 A8-A6',
        'master=A8 master=B8 topic=A7 topic=B5',
        'A1 B1-A1 A2-B1 B2-A2 A4-B2 B4-A4 B6-B4 A3-B2 B3-A3 A5-B4B3 B5-A5 B7-B5 B8-B7 A7-A5 A6-B8 A8-A6',
        'The two master branches should be the same'
    ],
);

# useful hack for quick testing
@tests = grep  { $_ } @tests[@ARGV] if @ARGV;

plan skip_all => 'No test selected' if !@tests;
plan tests => scalar @tests;

# the program we want to test
my $gsr = File::Spec->rel2abs('script/git-stitch-repo');
my $lib = File::Spec->rel2abs('lib');

for my $t (@tests) {
    my ( $src, $refs, $dst, $todo ) = @$t;

    # a temporary directory for our tests
    my $dir = File::Spec->rel2abs( tempdir( 'git-XXXXX', CLEANUP => !@ARGV ) );

    # create the source repositories
    my @src = create_repos( $dir => $src, $refs );

    # create the destination repository
    my $repo = new_repo( $dir => 'RESULT' );

    # run git-stitch-repo on the source repositories
    my ( $in, $out );
    my $pid
        = open2( $out, $in, $^X, "-I$lib", $gsr, map { $_->wc_path } @src );

    # run git-fast-import on the destination repository
    my ( $fh, $c ) = $repo->command_input_pipe( 'fast-import', '--quiet' );

    # pipe the output of git-stitch-repo into git-fast-import
    while (<$out>) {
        next if /^progress /;    # ignore progress info
        print {$fh} $_;
    }
    $repo->command_close_pipe( $fh, $c );

    # get the description of the resulting repository
    my $result = repo_description($repo);
    if ($todo) {
    TODO: {
            local $TODO = $todo;
            is( $result, $dst, "$src => $dst" );
        }
    }
    else {
        is( $result, $dst, "$src => $dst" );
    }
}

