use Test::More;
use Cwd qw( cwd );
use Test::Git;
use Git::Repository;
use Git::FastExport;
use File::Temp qw( tempdir );

has_git( '1.5.0' );

# setup a temporary git repo
my $r = test_repository();

my $version    = $r->version;
my $version_ok = $r->version_ge('1.5.4');

my @tests = (

    # desc, args
    [ 'Git::Repository', $r ],
    [ 'directory', $r->work_tree ],
    [ '' ],
);

my @fails = (

    # desc, error regex, args
    [ 'non-existent directory', qr/^Can't chdir to .*zlonk/, 'zlonk' ],
    [ 'non-Git::Repository object', qr/^Can't chdir to .*Zlonk=/, bless {}, 'Zlonk' ],
  ( [ "git $version", qr/^Git version 1\.5\.4 required for git fast-export\./ ] )x! $version_ok,
);

plan tests => 3 * @tests + 3 * @fails;

my $home = cwd();

chdir $r->work_tree;

SKIP: {
    skip "Git 1.5.4 required, this is only $version", 3 * @tests
      if !$version_ok;
    for my $t (@tests) {
        my ( $desc, @args ) = @$t;
        my $export;
        ok( eval { $export = Git::FastExport->new(@args); 1 },
            "Git::FastExport->new($desc)" );
        is( $@, '', "No error calling Git::FastExport->new($desc)" );
        isa_ok( $export, 'Git::FastExport' );
    }
}

# some failure tests
for my $t (@fails) {
    my ( $desc, $regex, @args ) = @$t;
    my $export;
    ok( !eval { $export = Git::FastExport->new(@args); 1 },
        "Git::FastExport->new() failed with $desc" );
    like( $@, $regex, 'Expected error message' );
    is( $export, undef, 'No object created' );
}

chdir $home;
