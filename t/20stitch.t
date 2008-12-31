use strict;
use warnings;
use Test::More;
use t::Utils;
use Git::FastExport::Stitch;

# all possible valid options
my @valid_args = map {
    my %o = %$_;
    ( \%o, map { my %h = %o; $h{select} = $_; \%h } qw( first last random ) )
} ( {}, { cache => '' }, { cache => 1 } );

my @tests = (

    # args, error
    [ [] ],
    map( { [ [ $_ ] ] } @valid_args ),

    # error cases
    [ [ { select => 'bam' } ], qr/Invalid value for 'select' option: 'bam'/ ],
);

plan tests => 2 * @tests;

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

