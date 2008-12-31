package Git::FastExport::Stitch;

use strict;
use warnings;
use Carp;

sub new {
    my ( $class, $options, @args ) = @_;

    # create the object
    my $self = bless {

        # internal structures
        repo => {},
        name => 'A',

        # default options
        select => 'last',
        cache  => 1,

    }, $class;

    # set the options
    for my $key (qw( select cache )) {
        $self->{$key} = $options->{$key} if exists $options->{$key};
    }
    croak "Invalid value for 'select' option: '$self->{select}'"
        if $self->{select} !~ /^(?:first|last|random)$/;

    return $self;
}

1;

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

