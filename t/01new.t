use Test::More;
use Cwd qw( cwd );
use Test::Git;
use Git::Repository;
use Git::FastExport;
use File::Temp qw( tempdir );

has_git();

# setup a temporary git repo
my $r = test_repository();

my @tests = (

    # desc, args
    [ 'Git::Repository', $r ],
    [ 'directory', $r->work_tree ],
    [ '' ],
);

my @fails = (

    # desc, error regex, args
    [ q('zlonk'), qr/^Can't chdir to .*zlonk/, 'zlonk' ],
    [ q('zlonk'), qr/^Can't chdir to .*Zlonk=/, bless {}, 'Zlonk' ],
);

plan tests => 3 * @tests + 3 * @fails;

my $home = cwd();

chdir $r->work_tree;

for my $t (@tests) {
    my ( $desc, @args ) = @$t;
    my $export;
    ok( eval { $export = Git::FastExport->new(@args); 1 },
        "Git::FastExport->new($desc)" );
    is( $@, '', "No error calling Git::FastExport->new($desc)" );
    isa_ok( $export, 'Git::FastExport' );
}

# some failure tests
for my $t (@fails) {
    my ( $desc, $regex, @args ) = @$t;
    my $export;
    ok( !eval { $export = Git::FastExport->new(@args); 1 },
        "Git::FastExport->new($desc) failed" );
    like( $@, $regex, 'Expected error message' );
    is( $export, undef, 'No object created' );
}

chdir $home;
