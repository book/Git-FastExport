use strict;
use warnings;
use File::Path;
use File::Spec;
use Git;

1;

# create a new, empty repository
sub new_repo {
    my ( $dir, $name ) = @_;

    # alas, this can't be done with Git.pm
    my $wc = File::Spec->rel2abs( File::Spec->catfile( $dir, $name ) );
    mkpath $wc;
    chdir $wc;
    `git-init`;
    return Git->repository( Directory => $wc );
}

# produce a text description of a given repository
sub repo_description {
    my ($repo) = @_;
    my %log;    # map sha1 to log message
    my @commits;

    # process the whole tree
    my ( $fh, $c )
        = $repo->command_output_pipe( 'log', '--pretty=format:%H-%P-%s',
        '--date-order', '--all' );
    while (<$fh>) {
        chomp;
        my ( $h, $p, $log ) = split /-/, $_, 3;
        $log{$h} = $log;
        $p =~ y/ //d;
        push @commits, $p ? "$log-$p" : $log;
    }
    $repo->command_close_pipe( $fh, $c );

    # replace SHA-1 by log name
    my $desc = join ' ', reverse @commits;
    $desc =~ s/(\w{40})/$log{$1}/g;

    return $desc;
}

