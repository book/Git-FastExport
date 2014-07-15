package Git::FastExport;

use strict;
use warnings;
use Carp;
use Scalar::Util qw( blessed );

use Git::Repository;
use Git::FastExport::Block;

sub new {
    my ( $class, $repo ) = @_;
    my $self = bless { source => '' }, $class;

    $self->{git} = blessed $repo && $repo->isa('Git::Repository')
        ? $repo    # below, use "$repo" for Path::Class paths
        : Git::Repository->new( defined $repo ? ( { cwd => "$repo" } ) : () );

    return $self;
}

sub fast_export {
    my ( $self, @args ) = @_;
    my $repo = $self->{git};
    $self->{source} = $repo->work_tree || $repo->git_dir;

    # call the fast-export command (no default arguments)
    $self->{command} = $repo->command( 'fast-export', @args );
    $self->{export_fh} = $self->{command}->stdout;
}

sub next_block {
    my ($self) = @_;

    my $fh = $self->{export_fh};
    die "fast_export() must be called before next_block()" if !$fh;

    # are we done?
    if ( eof $fh ) {
        if ( $self->{command} ) {
            $self->{command}->close;
            delete $self->{command};
        }
        delete $self->{export_fh};
        return;
    }

    my $block = bless {}, 'Git::FastExport::Block';

    # use the header from last time, or read it (first time)
    $block->{header} = $self->{header} ||= <$fh>;
    chomp $block->{header};
    ( $block->{type} ) = $block->{header} =~ /^(\w+)/g;

    local $_;
    while (<$fh>) {

        # we've reached the beginning of the next block
        if (/^(commit|tag|reset|blob|checkpoint|progress|feature|option)\b/) {
            s/^progress /progress [$self->{source}] /;
            $self->{header} = $_;
            last;
        }

        chomp;

        # special case of data block
        if (/^data (\d+)/) {
            my $bytes= 0 + $1;
            if ($bytes) {
                local $/ = \$bytes;
                $block->{data} = <$fh>;
            } else {
                $block->{data} = "";
            }
        }
        elsif (/^(?:[MDRC] |deleteall)/) {
            push @{ $block->{files} }, $_;
        }
        elsif (/^(\w+)/) {
            push @{ $block->{$1} }, $_;
        }
        else {

            # ignore empty lines, but choke on others
            die "Unexpected line:\n$_\n" if !/^$/;
            $block->{footer} .= "\012";
        }
    }

    # post-processing
    if ( $block->{type} eq 'commit' ) {
        ( $block->{committer_date} )
            = $block->{committer}[0] =~ /^committer [^>]*> (\d+) [-+]\d+$/g;
        ( $block->{author_date} )
            = $block->{author}[0] =~ /^author [^>]*> (\d+) [-+]\d+$/g;
    }

    return $block;
}

'progress 1 objects';

__END__

# ABSTRACT: A module to parse the output of git-fast-export

=head1 SYNOPSIS

    use Git::Repository;
    use Git::FastExport;

    # get the object from a Git::Repository
    my $repo = Git::Repository->new( work_tree => $path );
    my $export = Git::FastExport->new($repo);

    # or simply from a path specification
    my $export = Git::FastExport->new($path);

    while ( my $block = $export->next_block() ) {

        # do something with $block

    }

=head1 DESCRIPTION

L<Git::FastExport> is a module that parses the output of
B<git-fast-export> and returns L<Git::FastExport::Block> objects that
can be inspected or modified before being eventually passed on as the
input to B<git-fast-import>.

=head1 METHODS

This class provides the following methods:

=over 4

=item new( [ $repository ] )

The constructor takes an optional L<Git::Repository> object,
or a path (to a C<GIT_DIR> or C<GIT_WORK_TREE>), and returns a
L<Git::FastExport> object attached to it.

=item fast_export( @args )

Initialize a B<git-fast-export> command on the repository, using the
arguments given in C<@args>.

=item next_block()

Return the next block in the B<git-fast-export> stream as a
L<Git::FastExport::Block> object.

Return nothing at the end of stream.

This methods reads from the C<export_fh> filehandle of the L<Git::FastExport>
object. It is normally setup via the C<fast_export()> method, but it is
possible to make it read directly from C<STDIN> (or another filehandle) by doing:

    $export->{export_fh} = \*STDIN;
    while ( my $block = $export->next_block() ) {
        ...
    }

=back

=head1 ACKNOWLEDGEMENTS

The original version of this module was created as part of my work
for BOOKING.COM, which authorized its publication/distribution
under the same terms as Perl itself.

=head1 COPYRIGHT

Copyright 2008-2014 Philippe Bruhat (BooK), All Rights Reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
