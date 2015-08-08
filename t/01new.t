use strict;
use warnings;
use Test::More;
use Git::FastExport;

plan tests => 4;

my $export;

# no filehandle
$export = Git::FastExport->new();
isa_ok( $export, 'Git::FastExport' );
is( $export->next_block, undef, 'no filehandle returns nothing' );

# make sure we won't read anything by accident
close *STDIN;
@ARGV = ();

# empty filehandle
$export = Git::FastExport->new( \*ARGV );
isa_ok( $export, 'Git::FastExport' );
is( $export->next_block, undef, 'empty filehandle returns nothing' );
