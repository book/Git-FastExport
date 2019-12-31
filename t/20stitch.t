use strict;
use warnings;
use Test::More;
use lib 't/lib';
use TestUtils;
use File::Path;
use Git::FastExport::Stitch;
use Test::Requires::Git;

test_requires_git('1.5.4');

# all possible valid options
my @valid_args = map {
    my %o = %$_;
    ( \%o, map { my %h = %o; $h{select} = $_; \%h } qw( first last random ) )
} ( {}, { cached => '' }, { cached => 1 } );

my @tests = (

    # args, error
    [ [] ],
    map( { [ [ $_ ] ] } @valid_args ),

    # error cases
    [ [ { select => 'bam' } ], qr/Invalid value for 'select' option: 'bam'/ ],
    [ [ {}, 'bonk' ], qr/^Can't chdir to .*bonk: / ],
);


plan tests => 2 * @tests + 5;

for my $t (@tests) {
    my ( $args, $error ) = @$t;
    my $export = eval { Git::FastExport::Stitch->new(@$args) };

    my $code = 'new(' . description_of(@$args) . ')';
    if ($error) {
        ok( !$export, "$code failed" );
        like( $@, $error, 'Expected error message' );
    }
    else {
        ok( $export, "$code passed" );
        diag $@ if $@;    # in case it failed
        isa_ok( $export, 'Git::FastExport::Stitch' );
    }

}

# check we croak when stitching several times the same repo
my $dir = File::Spec->rel2abs( File::Spec->catdir( 'git-test', '_' ) );
rmtree( [ $dir ] );
my @r = build_repositories( 'A1', 'master=A1', $dir );

my $export = eval { Git::FastExport::Stitch->new() };
ok( eval { $export->stitch( $r[0]->work_tree ) }, 'stitch( A ) passed' );
diag $@ if $@;
ok( !eval { $export->stitch( $r[0]->work_tree ) }, 'stitch( A ) failed' );
like( $@, qr(^Already stitching repository .*A), 'Expected error message' );
ok( !eval { $export->stitch( $r[0] ) }, 'stitch( A ) failed' );
like( $@, qr(^Already stitching repository .*A), 'Expected error message' );

