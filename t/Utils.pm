use strict;
use warnings;
use Git;

1;

# produce a text description of a given repository
sub repo_description {
    my ($repo) = @_;
    my %log;    # map sha1 to log message
    my $desc;

    # process the whole tree
    my ( $fh, $c )
        = $repo->command_output_pipe( 'log', '--pretty=format:%H-%P-%s',
        '--date-order', '--all' );
    while (<$fh>) {
        print;
        chomp;
        my ( $h, $p, $log ) = split /-/, $_, 3;
        $log{$h} = $log;
        $p =~ y/ //d;
        $desc = join ' ', $p ? "$log-$p" : $log, $desc;
    }
    $repo->command_close_pipe( $fh, $c );

    # replace SHA-1 by log name
    $desc =~ s/(\w{40})/$log{$1}/g;

    return $desc;
}

