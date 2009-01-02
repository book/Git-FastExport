use strict;
use warnings;
use File::Spec;
use IPC::Open3;
use Test::More;

my @scripts = glob File::Spec->catfile( script => '*' );

plan tests => scalar @scripts;

for my $script (@scripts) {
    local ( *IN, *OUT, *ERR );
    my $pid = open3( \*IN, \*OUT, \*ERR, $^X,  '-Mblib', '-c', $script );
    my $errput = <ERR>;
    like( $errput, qr/syntax OK/, "'$script' compiles" );
}

