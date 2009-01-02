package Git::FastExport::Stitch;

use strict;
use warnings;
use Carp;
use Scalar::Util qw( blessed );
use List::Util qw( first );
use Git::FastExport;

our $VERSION = '0.07';

'progress 1 objects';

sub new {
    my ( $class, $options, @args ) = @_;

    # create the object
    my $self = bless {

        # internal structures
        mark     => 1_000_000,    # mark counter in the new repo
        mark_map => {},
        commits  => {},
        repo     => {},
        name     => 'A',
        cache    => {},

        # default options
        select => 'last',
        cached => 1,

    }, $class;

    # set the options
    for my $key (qw( select cached )) {
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

    # set up the internal structures
    $export->{mapdir}            = $dir;
    $self->{repo}{$repo}{repo}   = $repo;
    $self->{repo}{$repo}{dir}    = $dir;
    $self->{repo}{$repo}{parser} = $export;
    $self->{repo}{$repo}{name}   = $self->{name}++;
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

    # select the oldest alvailable commit
    my ($next) = keys %$repo;
    $next
        = $repo->{$next}{block}{date} < $repo->{$_}{block}{date} ? $next : $_
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
    my $branch = ( split / /, $commit->{header} )[1];
    my $node = $commits->{$id} = {
        name     => $id,
        repo     => $repo->{repo},
        branch   => $branch,
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
        for my $repo ( keys %{ $commits->{$parent}{parents} } ) {
            $parents->{$repo}{$_} = 1
                for keys %{ $commits->{$parent}{parents}{$repo} };
        }
    }

    # map each parent to its last "alien" commit
    my %parent_map = map {
        $_ => $self->_last_alien_child( $commits->{$_}, $branch, $parents )->{name}
    } @parents;

    # map parent marks
    for ( @{ $commit->{from} || [] }, @{ $commit->{merge} || [] } ) {
        s/:(\d+)/:$parent_map{$1}/g;
    }

    # update the parents information
    $self->_add_parents( $node => map { $commits->{ $parent_map{$_} } } @parents );

    # dump the commit
    return $commit;
}

sub _translate_block {
    my ( $self, $repo ) = @_;
    my $mark_map = $self->{mark_map};
    my $block    = $self->{repo}{$repo}{block};

    # nothing to do
    return if !defined $block;

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
        if ( my $dir = $self->{repo}{$repo}{dir} ) {
            s!^(M \d+ :\d+) (.*)!$1 $dir/$2!;    # filemodify
            s!^D (.*)!D $dir/$1!;                # filedelete

            # /!\ quotes may happen - die and fix if needed
            die "Choked on quoted paths in $repo! Culprit:\n$_\n"
                if /^[CR] \S+ \S+ /;

            # filecopy | filerename
            s!^([CR]) (\S+) (\S+)!$1 $dir/$2 $dir/$3!;
        }
    }
}

# given a commit (item from $self->{commits})
# add the parents from the given commits to it
sub _add_parents {
    my ( $self, $node, @parents ) = @_;

    for my $parent (@parents) {
        push @{ $parent->{children} }, $node->{name};
        for my $repo_name ( keys %{ $parent->{parents} } ) {
            $node->{parents}{$repo_name}{$_} = 1
                for keys %{ $parent->{parents}{$repo_name} || {} };
        }
        $node->{parents}{ $parent->{repo} }{ $parent->{name} } = 1;
    }

    return $node;
}

# find the last child of this node
# that has either no child
# or a child in our repo
# or an alien child that has the same parent list
sub _last_alien_child {
    my ( $self, $node, $branch, $parents ) = @_;
    my $commits = $self->{commits};

    my $from = $node->{name};
    my $repo = $node->{repo};
    my $old  = '';

    while ( $node ne $old ) {
        $old = $node;

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
            next
                if grep { !exists $peer->{parents}{ $peer->{repo} }{$_} }
                    keys %{ $parents->{ $peer->{repo} } };

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

__END__

=head1 NAME

Git::FastExport::Stitch - Stitch together multiple git fast-export streams 

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

C<Git::FastExport::Stich> is a module that "stitches" together several
git fast-export streams. This module is the core of the B<git-stitch-repo>
utility.

C<Git::FastExport::Stitch> objects can be used as C<Git::FastExport>,
since they support the same inteface for the C<next_block()> method.

=head1 METHODS

C<Git::FastExport::Stitch> supports the following methods:

=over 4

=item new( \%options, [ ... ] )

Create a new C<Git::FastExport::Stitch> object.

The options hash defines options that will be used during the creation of the stitched repository.

The B<select> option defines the selection algorithm to be used when the I<last alien child>
algorithm reaches a branch point. Valid values are: C<first>, C<last> and C<random>. The
default value is C<last>.

The B<cache> option determines if the result of the selection algorithm is cached or not.
It is a boolean value. The default value is I<true>.

See L<STITCHING ALGORITHM> for details about what these options really mean.

The remaining parameters (if any) are taken to be parameters (passed by
pairs) to the C<stitch()> method.

=item stitch( $repo, $dir )

Add the given C<$repo> to the list of repositories to stitch in.

C<$repo> can be either a directory, or a C<Git> object (both will
be used to instantiate a C<Git::FastExport> object) or directly a
C<Git::FastExport> object.

The optional C<$dir> parameter will be used as the relative directory
under which the trees of the source repository will be stored in the
stitched repository.

=item next_block()

Return the next block of the stitched repository, as a
C<Git::FastExport::Block> object.

Return nothing at the end of stream.

=back

=head1 STITCHING ALGORITHM

=head1 INTERNAL METHODS

To run the stitching algorithm, C<Git::FastExport::Stitch> makes
use of several internal methods.  These are B<not> part of the public
interface of the module, and are detailed below for those interested in
the algorithm itself.

=over 4

=item _translate_block( $repo )

Given a I<repo> key in the internal structure listing all the repositories
to stitch together, this method "translates" the current block using
the references (marks) of the resulting repository.

To ease debugging, the translated mark count starts at C<1_000_000>.

=item _add_parents( $node, @parents )

Add the given parents to the node, and update the internal structure
containing the node lineage.

=item _last_alien_child( $node, $branch, $parents )

Given a node, its "branch" name (actually, the reference given on the
C<commit> line of the fast-export) and a structure describing it's
lineage over the various source repositories, find a suitable commit to
which attach it.

This method is the heart of the stitching algorithm.

=back

=head1 SEE ALSO

B<git-stitch-repo>

=head1 AUTHOR

Philippe Bruhat (BooK)

=head1 COPYRIGHT

Copyright 2008-2009 Philippe Bruhat (BooK), All Rights Reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

