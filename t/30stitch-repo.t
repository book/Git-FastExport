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

);

# useful hack for quick testing
@tests = @tests[@ARGV] if @ARGV;

plan tests => scalar @tests;

# the program we want to test
my $gsr = File::Spec->rel2abs('script/git-stitch-repo');
my $lib = File::Spec->rel2abs('lib');

for my $t (@tests) {
    my ( $src, $refs, $dst, $todo ) = @$t;

    # a temporary directory for our tests
    my $dir = File::Spec->rel2abs( tempdir( 'git-XXXXX', CLEANUP => 1 ) );

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

