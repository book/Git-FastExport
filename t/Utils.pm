use strict;
use warnings;
use File::Path;
use File::Spec;
use Git::Repository;

# record the sha1 of the empty tree
my $TREE;

# cheap trick to ensure increasing commit dates
my $time = time;
sub options {
    $time++;
    return {
        env => {
            GIT_AUTHOR_DATE    => $time,
            GIT_COMMITTER_DATE => $time,
        }
    };
}

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
sub new_repo {
    my ( $dir, $name ) = @_;
    my $wc = File::Spec->rel2abs( File::Spec->catfile( $dir, $name ) );
    mkpath $wc;
    Git::Repository->run('init', { cwd => $wc } );
    my $repo = Git::Repository->new( work_tree => $wc, { quiet => 1 } );
    $repo->run(qw( config user.email test@example.com ));
    $repo->run(qw( config user.name  Test ));
    $TREE = $repo->run( mktree => { input => '' } );    # add the empty commit
    return $repo;
}

# produce a text description of a given repository
sub repo_description {
    my ($repo) = @_;
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
      for $repo->run(qw( log --pretty=format:%H-%P-%s --date-order --all ));

    # get the heads and tags
    %head = reverse map { s{ refs/heads/}{ }; split / / }
      $repo->run( 'show-ref', '--heads' );
    %tag = reverse map { s{ refs/tags/}{ }; split / / }
      $repo->run( 'show-ref', '--tags' );

    # look for annotated tags
    my %atag;
    for my $tag ( keys %tag ) {
        if ( my @tag = eval { $repo->run( 'cat-file', tag => $tag ) } ) {
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
    $desc =~ s/([0-9a-f]{40})/$log{$1}/g;

    return wantarray ? ( $desc, $refs ) : $desc;
}

# split a description into descriptions of independent repositories
sub split_description {
    my ($desc) = @_;
    my %desc;

    for my $node ( split / /, $desc ) {
        my ($repo) = $node =~ /^([A-Z]+)/;
        push @{ $desc{$repo} }, $node;
    }
    return map { join ' ', @$_ } values %desc;
}

# create a set of repositories from a given description
sub create_repos {
    my ( $dir, $desc, $refs ) = @_;
    my $info = { dir => $dir, repo => {}, sha1 => {} };

    for my $commit ( split / /, $desc ) {
        my ( $child, $parent ) = split /-/, $commit;
        my @parent = $parent =~ /([A-Z]+\d+)/g if $parent;
        create_commit( $info, $child, @parent );
    }

    # setup the refs (branches & tags)
    for my $ref ( split / /, $refs ) {
        my ( $name, $type, $commit ) = split /([>=])/, $ref;
        my ($repo_name) = $commit =~ /^([A-Z]+)/;
        my $repo = $info->{repo}{$repo_name};
        if ( $type eq '=' ) {    # branch
            $repo->run( 'update-ref', "refs/heads/$name", $info->{sha1}{$commit} );
        }
        else {                   # tag
            ($name, my $msg) = split /:/, $name;
            $repo->run( tag => ( '-m' => $msg )x!! $msg, $name, $info->{sha1}{$commit} );
        }
    }

    # return the repository objects
    return map { $info->{repo}{$_} } sort keys %{ $info->{repo} };
}

sub create_commit {
    my ( $info, $child, @parents ) = @_;
    my ($name) = $child =~ /^([A-Z]+)/g;

    # get the repository, or create a new one
    my $repo = $info->{repo}{$name} ||= new_repo( $info->{dir} => $name );

    # create the commit (with the empty tree)
    $info->{sha1}{$child} = $repo->run(
        'commit-tree' => $TREE,
        { input => $child }, options(),
        map +( '-p' => $info->{sha1}{$_} ), @parents
    );
}

1;
