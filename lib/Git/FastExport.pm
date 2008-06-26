package Git::FastExport;
use strict;
use warnings;
use Carp;
use Cwd;
use IPC::Open2;

our $VERSION = '0.01';

sub new {
    my ( $class, $repo ) = @_;
    my $self = bless { source => '' }, $class;

    if ($repo) {
        croak "$repo is not a Git object"
            if !( ref $repo && $repo->isa('Git') );
        $self->{git} = $repo;
    }
    return $self;
}

sub fast_export {
    my ( $self, @args ) = @_;
    my $repo = $self->{git};
    $self->{source} = $repo->wc_path || $repo->repo_path;

    # call the fast-export command (no default arguments)
    ( $self->{export_fh}, $self->{ctx} )
        = $repo->command_output_pipe( 'fast-export', @args );
}

sub next_block {
    my ($self) = @_;
    my $block = bless {}, 'Git::FastExport::Block';
    my $fh = $self->{export_fh};

    return if eof $fh;

    # use the header from last time, or read it (first time)
    $block->{header} = $self->{header} ||= <$fh>;
    chomp $block->{header};
    ( $block->{type} ) = $block->{header} =~ /^(\w+)/g;

    local $_;
    while (<$fh>) {

        # we've reached the beginning of the next block
        if (/^(commit|tag|reset|blob|checkpoint|progress)\b/) {
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
        ( $block->{date} )
            = $block->{committer}[0] =~ /^committer [^>]*> (\d+) [-+]\d+$/g;
    }

    return $block;
}

package Git::FastExport::Block;

my $LF = "\012";

my %fields = (
    commit     => [qw( mark author committer data from merge files )],
    tag        => [qw( from tagger data )],
    reset      => [qw( from )],
    blob       => [qw( mark data )],
    checkpoint => [],
    progress   => [],
);

sub as_string {
    my ($self) = @_;
    my $string = $self->{header} . $LF;

    for my $key ( @{ $fields{ $self->{type} } } ) {
        next if !exists $self->{$key};
        if ( $key eq 'data' ) {
            $string
                .= 'data ' . length( $self->{data} ) . $LF . $self->{data};
        }
        else {
            $string .= "$_$LF" for @{ $self->{$key} };
        }
    }
    return $string .= $self->{footer} || '';
}

1;

__END__

=head1 NAME

Git::FastExport - A module to parse the output of git-fast-export

=head1 SYNOPSIS

    use Git;
    use Git::FastExport;

    my $repo = Git->repository( Repository => $path );
    my $export = Git::FastExport->new($repo);

    while ( my $block = $parser->next_block() ) {

        # do something with $block

    }

=head1 DESCRIPTION

C<Git::FastExport> is a module that parses the output of
B<git-fast-export> and returns C<Git::FastExport::Block> objects that
can be inspected or modified before being eventually passed on as the
input to B<git-fast-import>.

=head1 METHODS

This class provides the following methods:

=over 4

=item new( [ $repository ] )

The constructor takes an optional C<Git> repository object, and returns
a C<Git::FastExport> object attached to it.

=item fast_export( @args )

Initialize a B<git-fast-export> command on the repository, using the
arguments given in C<@args>.

=item next_block()

Return the next block in the B<git-fast-export> stream as a
C<Git::FastExport::Block> object.

Return nothing at the end of stream.

This methods reads from the C<export_fh> filehandle of the C<Git::FastExport>
object. It is normally setup via the C<fast_export()> method, but it is
possible to read from STDIN by doing:

    $export->{export_fh} = \*STDIN;
    while ( my $block = $export->next_block() ) {
        ...
    }

=back

=head1 AUTHOR

Philippe Bruhat (BooK)

=head1 ACKNOWLEDGEMENTS

The original version of this module was created as part of my work
for BOOKING.COM, which authorized its publication/distribution
under the same terms as Perl itself.

=head1 COPYRIGHT

Copyright 2008 Philippe Bruhat (BooK), All Rights Reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

