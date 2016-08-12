use strict;
use warnings;

use File::Spec;
use File::Path qw( mkpath );
use File::Temp qw( tempdir );
use Git::Repository;

my $TREE;    # sha1 of the empty tree

# helper function for nicer test messages
sub description_of {

    # interpolate with comma's in this scope
    local $" = ', ';

    # silence screaming about undefined values
    no warnings 'uninitialized';

    my @desc;
    for my $v (@_) {
        push @desc,
            !defined $v ? '<undef>'
            : $v     eq ''      ? "''"
            : ref $v eq 'ARRAY' ? "[ @$v ]"
            : ref $v eq 'HASH'  ? "{ @{[map{qq'$_ => $v->{$_}'}sort keys%$v]} }"
            : $v;
    }

    return "@desc";
}

# create a new, empty repository
sub create_repository {
    my ($dir) = @_;
    mkpath $dir;
    Git::Repository->run( 'init', { cwd => $dir } );
    my $r = Git::Repository->new( work_tree => $dir, { quiet => 1 } );
    $r->run(qw( config user.email test@example.com ));
    $r->run(qw( config user.name  Test ));
    $TREE = $r->run( mktree => { input => '' } );    # add the empty tree
    return $r;
}

# produce a text description of a given repository
sub describe_repository {
    my ($r) = @_;
    my %log;    # map sha1 to log message
    my @commits;

    my ( %head, %tag );

    # extract the relevant information from the repository
    do {
        my ( $h, $p, $log ) = split /-/, $_, 3;
        $log{$h} = $log;
        $p =~ y/ //d;
        push @commits, $p ? "$log-$p" : $log;
      }
      for $r->run(qw( log --pretty=format:%H-%P-%s --date-order --all ));

    # get the heads and tags
    %head = reverse map { s{ refs/heads/}{ }; split / / }
      $r->run( 'show-ref', '--heads' );
    %tag = reverse map { s{ refs/tags/}{ }; split / / }
      $r->run( 'show-ref', '--tags' );

    # look for annotated tags
    my %atag;
    for my $tag ( keys %tag ) {
        if ( my @tag = eval { $r->run( 'cat-file', tag => $tag ) } ) {
            my ($commit) = ( split / /, $tag[0] )[-1];    # tagged a commit
            $atag{$tag} = [ $commit, $tag[-1] ];          # 1-line msg
            delete $tag{$tag};
        }
    }

    # compute $refs
    my $refs = join ' ', sort
        map( "$_=$log{$head{$_}}",                 keys %head ),
        map( "$_:$atag{$_}[1]>$log{$atag{$_}[0]}", keys %atag ),
        map( "$_>$log{$tag{$_}}",                  keys %tag );

    # replace SHA-1 by log name
    my $desc = join ' ', reverse @commits;
    $desc =~ s/([a-f0-9]{40})/$log{$1}/g;

    return wantarray ? ( $desc, $refs ) : $desc;
}

# A repository description is a string constructed as follows:
# - each repository is named after an uppercase letter (A .. Z)
# - commits are numbered (A1, B1, A2, etc)
# - a commit's parent are prepended to it using a dash: A1-A2
# - commits are listed in chronological order, separated by a space
#
# References are defined with another string (and space-separated):
# - branches:         master=A4
# - lightweight tags: tag1>B3
# - annotated tags:   tag2:mesg>A2
#
sub build_repositories {
    my ( $commits, $refs, $dir ) = @_;
    $dir ||= tempdir( CLEANUP => 1 );
    my $now = time;

    my ( %r, %sha );
    for my $commit ( split / /, $commits ) {
        my ( $child, $parent ) = split /-/, $commit;
        my ($name) = $child =~ /^([A-Z]+)/g;
        my @parents = $parent =~ /([A-Z]+\d+)/g if $parent;

        # create the repository if needed
        my $r = $r{$name} ||= create_repository(
            File::Spec->rel2abs( File::Spec->catfile( $dir, $name ) ) );

        # create the commit (using the empty tree)
        $now++;    # advance time to ensure increasing commit dates
        $sha{$child} = $r->run(
            'commit-tree' => $TREE,
            {
                input => $child,
                env   => {
                    GIT_AUTHOR_DATE    => $now,
                    GIT_COMMITTER_DATE => $now,
                },
            },
            map +( '-p' => $sha{$_} ),
            @parents
        );
    }

    # setup the refs (branches & tags)
    for my $ref ( split / /, $refs ) {
        my ( $name, $type, $commit ) = split /([>=])/, $ref;
        my ($repo_name) = $commit =~ /^([A-Z]+)/;
        my $r = $r{$repo_name};
        if ( $type eq '=' ) {    # branch
            $r->run( 'update-ref', "refs/heads/$name", $sha{$commit} );
        }
        else {                   # tag
            ($name, my $msg) = split /:/, $name;
            $r->run( tag => ( '-m' => $msg )x!! $msg, $name, $sha{$commit} );
        }
    }

    # return the repository objects
    return values %r;
}

1;
