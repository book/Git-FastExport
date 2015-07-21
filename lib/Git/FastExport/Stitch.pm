package Git::FastExport::Stitch;

use strict;
use warnings;
use Carp;
use Scalar::Util qw( blessed );
use List::Util qw( first );
use File::Basename qw( basename );
use Git::FastExport;

sub new {
    my ( $class, $options, @args ) = @_;

    # create the object
    my $self = bless {

        # internal structures
        mark     => 1_000_000,    # mark counter in the new repo
        mark_map => {},
        commits  => {},
        repo     => {},
        name     => {},
        cache    => {},

        # default options
        select => 'last',

    }, $class;

    # set the options
    for my $key (qw( select )) {
        $self->{$key} = $options->{$key} if exists $options->{$key};
    }
    croak "Invalid value for 'select' option: '$self->{select}'"
        if $self->{select} !~ /^(?:first|last|random)$/;

    # process the remaining args
    $self->stitch( splice @args, 0, 2 ) while @args;

    return $self;
}

# add a new repo to stich in
sub stitch {
    my ( $self, $repo, $dir ) = @_;

    my $export
        = blessed($repo) && $repo->isa('Git::FastExport')
        ? $repo
        : eval { Git::FastExport->new($repo) };
    $@ =~ s/ at .*\z//s, croak $@ if !$export;

    # initiate the Git::FastExport stream
    $export->fast_export(qw( --progress=1 --all --date-order ))
        if !$export->{export_fh};

    # do not stich a repo with itself
    $repo = $export->{source};
    croak "Already stitching repository $repo" if exists $self->{repo}{$repo};

    # pick the refs suffix:
    # use basename without the .git extension or non ASCII characters
    my $name = basename( $repo, '.git' );
    $name =~ y/-A-Za-z0-9_/-/cs;
    $name =~ s/^-|-$//g;
    $dir = $name if not defined $name;    # pick up a default name for the directory

    # check if the name is not used already and pick a replacement if it is
    if ( exists $self->{name}{$name} ) {
        my $suffix = "A";
        $suffix++ while ( exists $self->{name}{"$name-$suffix"} );
        $name .= "-$suffix";
    }

    # set up the internal structures
    $self->{repo}{$repo}{repo}   = $repo;
    $self->{repo}{$repo}{dir}    = $dir;
    $self->{repo}{$repo}{parser} = $export;
    $self->{repo}{$repo}{name}   = $name;
    $self->{repo}{$repo}{block}  = $export->next_block();
    $self->_translate_block( $repo );

    return $self;
}

# return the next block in the stitched stream
sub next_block {
    my ($self) = @_;
    my $repo = $self->{repo};

    # keep a list of next blocks (per repo)
    # any undef block means the stream is finished
    delete $repo->{$_} for grep { !defined $repo->{$_}{block} } keys %$repo;

    # no repo left, we're done
    return if ! keys %$repo;

    # return any non-commit block directly
    if ( my $next
        = first { $repo->{$_}{block}{type} ne 'commit' } keys %$repo )
    {
        my $block = $repo->{$next}{block};
        $repo->{$next}{block} = $repo->{$next}{parser}->next_block();
        $self->_translate_block( $next );
        return $block;
    }

    # select the oldest available commit
    my ($next) = keys %$repo;
    $next
        = $repo->{$next}{block}{committer_date} < $repo->{$_}{block}{committer_date} ? $next : $_
        for keys %$repo;
    my $commit = $repo->{$next}{block};

    # fetch the next block
    $repo->{$next}{block} = $repo->{$next}{parser}->next_block();
    $self->_translate_block( $next );

    # prepare the attachement algorithm
    $repo = $repo->{$next};
    my $commits  = $self->{commits};

    # first commit in the old repo linked to latest commit in new repo
    if ( $self->{last} && !$commit->{from} ) {
        $commit->{from} = ["from :$self->{last}"];
    }

    # update historical information
    my ($id) = $commit->{mark}[0] =~ /:(\d+)/g;
    $self->{last} = $id;    # last commit applied
    my $ref = ( split / /, $commit->{header} )[1];
    my $node = $commits->{$id} = {
        name     => $id,
        repo     => $repo->{repo},
        ref      => $ref,
        children => [],
        parents  => {},
        merge    => exists $commit->{merge},
    };

    # mark our original source
    $commit->{header} =~ s/$/-$repo->{name}/;

    # this commit's parents
    my @parents = map {/:(\d+)/g} @{ $commit->{from} || [] },
        @{ $commit->{merge} || [] };

    # get the reference parent list used by _last_alien_child()
    my $parents = {};
    for my $parent (@parents) {
        if ( $commits->{$parent}{repo} eq $node->{repo} ) {
            push @{ $parents->{ $node->{repo} } }, $parent;
        }
        else {    # record the parents from the other repositories
            for my $repo ( grep $_ ne $node->{repo},
                keys %{ $commits->{$parent}{parents} } )
            {
                push @{ $parents->{$repo} },
                    @{ $commits->{$parent}{parents}{$repo} || [] };
            }
        }
    }

    # map each parent to its last "alien" commit
    my %parent_map = map {
        $_ => $self->_last_alien_child( $commits->{$_}, $ref, $parents )->{name}
    } @parents;

    # map parent marks
    for ( @{ $commit->{from} || [] }, @{ $commit->{merge} || [] } ) {
        s/:(\d+)/:$parent_map{$1}/g;
    }

    # update the parents information
    for my $parent ( map { $commits->{ $parent_map{$_} } } @parents ) {
        push @{ $parent->{children} }, $node->{name};
        push @{ $node->{parents}{ $parent->{repo} } }, $parent->{name};
    }

    # dump the commit
    return $commit;
}

sub _translate_block {
    my ( $self, $repo ) = @_;
    my $mark_map = $self->{mark_map};
    my $block    = $self->{repo}{$repo}{block};

    # nothing to do
    return if !defined $block;

    # mark our original source
    $block->{header} =~ s/$/-$self->{repo}{$repo}{name}/
        if $block->{type} =~ /^(?:reset|tag)$/;

    # map to the new mark
    for ( @{ $block->{mark} || [] } ) {
        s/:(\d+)/:$self->{mark}/;
        $mark_map->{$repo}{$1} = $self->{mark}++;
    }

    # update marks in from & merge
    for ( @{ $block->{from} || [] }, @{ $block->{merge} || [] } ) {
        s/:(\d+)/:$mark_map->{$repo}{$1}/g;
    }

    # update marks & dir in files
    for ( @{ $block->{files} } ) {
        s/^M (\d+) :(\d+)/M $1 :$mark_map->{$repo}{$2}/;
        my $dir = $self->{repo}{$repo}{dir};
        if ( defined $dir && $dir ne '' ) {
            s!^(M \d+ :\d+) (\"?)(.*)!$1 $2$dir/$3!;    # filemodify
            s!^D (\"?)(.*)!D $1$dir/$2!;                # filedelete

            # /!\ quotes may happen - die and fix if needed
            die "Choked on quoted paths in $repo! Culprit:\n$_\n"
                if /^[CR] \S+ \S+ /;

            # filecopy | filerename
            s!^([CR]) (\"?)(\S+) (\"?)(\S+)!$1 $2$dir/$3 $4$dir/$5!;
        }
    }
}

# find the last child of this node
# that has either no child
# or a child in our repo
# or an alien child that has the same parent list
sub _last_alien_child {
    my ( $self, $node, $ref, $parents ) = @_;
    my $commits = $self->{commits};

    my $from = $node->{name};
    my $repo = $node->{repo};

    while (1) {

        # no children nodes
        return $node if ( !@{ $node->{children} } );

        # some children nodes are local
        return $node
            if grep { $commits->{$_}{repo} eq $repo } @{ $node->{children} };

        # all children are alien to us
        my @valid;
        for my $id ( @{ $node->{children} } ) {

            my $peer = $commits->{$id};

            # parents of $peer in $peer's repo contains
            # all parents from $parent in $peer's repo
            my %pparents;
            @{pparents}{ @{ $peer->{parents}{ $peer->{repo} } || [] } } = ();
            next
                if grep !exists $pparents{$_},
                @{ $parents->{ $peer->{repo} } };

            # this child node has a valid parent list
            push @valid, $id;
        }

        # compute the commit to attach to, using the requested algorithm
        if (@valid) {
            my $node_id = $self->{cache}{"$from $node->{name}"} ||=
                  $self->{select} eq 'last'  ? $valid[-1]
                : $self->{select} eq 'first' ? $valid[0]
                :                              $valid[ rand @valid ];
            $node = $commits->{$node_id};
        }
    }

    # return last valid child
    return $node;
}

'progress 1 objects';

__END__

# ABSTRACT: Stitch together multiple git fast-export streams

=head1 SYNOPSIS

    # create a new stitch object
    my $export = Git::FastExport::Stitch->new();

    # stitch in several git fast-export streams
    # a git directory
    $export->stitch( A => 'A' );
    # a Git repository object
    $export->stitch( Git->repository( Directory => 'B' ) => 'B' );
    # a Git::FastExport object
    $export->stitch( Git::FastExport->new('C') => 'C' );

    # output the stitched stream
    while ( my $block = $export->next_block() ) {
        print $block->as_string();
    }

=head1 DESCRIPTION

L<Git::FastExport::Stich> is a module that "stitches" together several
git fast-export streams. This module is the core of the B<git-stitch-repo>
utility.

Git::FastExport::Stitch objects can be used as L<Git::FastExport>,
since they support the same inteface for the C<next_block()> method.

=head1 METHODS

Git::FastExport::Stitch supports the following methods:

=head2 new

    my $export = Git::FastExport::Stitch->new( \%option );

Create a new Git::FastExport::Stitch object.

The options hash defines options that will be used during the creation of the stitched repository.

The B<select> option defines the selection algorithm to be used when the I<last alien child>
algorithm reaches a branch point. Valid values are: C<first>, C<last> and C<random>. The
default value is C<last>.

See L<STITCHING ALGORITHM> for details about what these options really mean.

The remaining parameters (if any) are taken to be parameters (passed by
pairs) to the C<stitch()> method.

=head2 stitch

    # add the repository to the list of repositories to stitch
    $export->stitch( $repo => $dir );

Add the given C<$repo> to the list of repositories to stitch in.

C<$repo> can be either a directory, or a L<Git> object (both will
be used to instantiate a L<Git::FastExport> object) or directly a
L<Git::FastExport> object.

The optional C<$dir> parameter will be used as the relative directory
under which the trees of the source repository will be stored in the
stitched repository.

The basename of the C<$repo> repository (mapped to ASCII without the
F<.git> suffix) is used as the internal name for C<$repo>. This internal
name is used as a suffix on refs copied from C<$repo>. When there's a
collision, an extra suffix (C<-A>, C<-B>, etc.) is added.

=head2 next_block

    my $block = $export->next_block();

Return the next block of the stitched repository, as a
L<Git::FastExport::Block> object.

Return nothing at the end of stream.

=head1 STITCHING ALGORITHM

=head2 Commit attachment

Git::FastExport::Stitch processes the input commits in B<--date-order>
fashion, and builds the new graph by attaching the new commit to another
commit of the graph being constructed. It starts from the "original"
parents of the node, and tries do follow the graph as far as possible.

When a commit has several suitable child commits, it needs to make a
selection. There are currently three selection algorithms:

=over 4

=item last

Pick the last child commit, i.e. the most recent one.
This is the default.

=item first

Pick the first child commit, i.e. the oldest one.

=item random

Pick a random child.

=back

=head2 Example

Imagine we have two repositories A and B that we want to stitch into
a repository C so that all the files from A are in subdirectory F<A>
and all the files from B are in subdirectory F<B>.

Note: in the following ASCII art graphs, horizontal order is chronological.

Repository A:

             ,topic      ,master
          ,-A3------A5--A6
         /         /
    A1--A2------A4'

Branch I<master> points to A6 and branch I<topic> points to A3.

Repository B:

                     ,topic      ,master
          ,-B3------B5------B7--B8
         /                 /
    B1--B2------B4------B6'

Branch I<master> points to B8 and branch I<topic> points to B5.

The RESULT repository should preserve chronology, commit relationships and
branches as much as possible, while giving the impression that the
directories F<A/> & F<B/> did live side-by-side all the time.

Assuming additional timestamps not shown on the above graphs
(the commit order is A1, B1, A2, B2, A3, A4, B3, B4, A5, B5, B6, B7, B8, A6),
Git::FastExport::Stitch will produce a B<git-fast-import> stream that will
create the following history, depending on the value of B<--select>:

=over 4

=item I<last> (default)

                                         ,topic-B
                          ,-B3----------B5----.
                         /                     \      ,master-B
    A1--B1--A2--B2------A4------B4--A5------B6--B7---B8--A6
                 \                 /                      `master-A
                  `-A3------------'
                     `topic-A

=item I<first>

                      ,---------B4----------B6-.
                     /                          \     ,master-B
    A1--B1--A2--B2--A3------B3------A5--B5------B7---B8--A6
                 \   `topic-A      /     `topic-B         `master-A
                  `-----A4--------'

=item I<random>

In this example, there are only two places where the selection process
is triggered, and there are only two items to choose from each time.
Therefore the I<random> selection algorithm will produce 4 possible
different results.

In addition to the results shown above (C<last+last> and C<first+first>),
we can also obtain the two following graphs:

C<first+last>:

                     ,topic-A                         ,master-B
    A1--B1--A2--B2--A3--------------A5------B6--B7---B8--A6
                 \                 /           /          `master-A
                  `-----A4------B4'     B5----'
                         \             / `topic-B
                          `-B3--------'

C<last+first>:

                                                      ,master-B
    A1--B1--A2--B2------A4------B4----------B6--B7---B8--A6
                 \       \                     /          `master-A
                  \       `-B3------A5--B5----'
                   \               /     `topic-B
                    A3------------'
                     `topic-A

=back

=head2 Constraints of the stitching algorithm

Any mathematician will tell you there are many many ways to stitch two
DAG together. This programs tries very hard not to create inconsistent
history with regard to each input repository.

The algorithm used by Git::FastExport::Stitch enforces the following
rules when building the resulting repository:

=over 4

=item *

a commit is attached as far as possible in the DAG, starting from the
original parent

=item *

a commit is only attached to another commit in the resulting repository
that has B<exactly> the same ancestors list as the original parent
commits.

=item *

when there are several valid branches to follow when trying to find
a commit to attach to, use the selection process (I<last> or I<first>
commit (at the time of attachement), or I<random> commit)

=item *

branches starting from the same commit in a source repository will start
from the same commit in the resulting repository (this particular rule
can be lifted: adding an option for this in on the TODO list)

=back

=head1 BUGS & IMPROVEMENTS

The current implementation can probably be improved, and more options
added. I'm very interested in test repositories that do not give the
expected results.

=head1 INTERNAL METHODS

To run the stitching algorithm, Git::FastExport::Stitch makes
use of several internal methods. These are B<not> part of the public
interface of the module, and are detailed below for those interested in
the algorithm itself.

=head2 _translate_block

    $self->_translate_block( $repo );

Given a I<repo> key in the internal structure listing all the repositories
to stitch together, this method "translates" the current block using
the references (marks) of the resulting repository.

To ease debugging, the translated mark count starts at C<1_000_000>.

=head2 _last_alien_child

    my $commit = $self->_last_alien_child( $node, $ref, $parents )

Given a node, its ref name (actually, the reference given on the
C<commit> line of the fast-export) and a structure describing its
lineage over the various source repositories, find a suitable commit to
which attach it.

This method is the heart of the stitching algorithm.

=head1 SEE ALSO

B<git-stitch-repo>

=head1 COPYRIGHT

Copyright 2008-2014 Philippe Bruhat (BooK), All Rights Reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
