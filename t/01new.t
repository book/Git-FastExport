use Test::More;
use Git;
use Git::FastExport;
use File::Temp qw( tempdir );

# setup a temporary git repo
my $dir = tempdir( CLEANUP => 1 );

# alas, this can't be done with Git.pm
chdir $dir;
`git-init`;

my $git = Git->repository( Directory => $dir );

my @tests = (

    # desc, args
    [''],
    [ "Git->new( Directory => $dir )", $git ],
);

plan tests => 3 * @tests;

my $export;

for my $t (@tests) {
    my ( $desc, @args ) = @$t;
    my $export;
    ok( eval { $export = Git::FastExport->new(@args); 1 },
        "Git::FastExport->new($desc)" );
    is( $@, '', "No error calling Git::FastExport->new($desc)" );
    isa_ok( $export, 'Git::FastExport' );

}

