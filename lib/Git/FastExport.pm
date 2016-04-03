package Git::FastExport;

use strict;
use warnings;
use Carp;
use Scalar::Util qw( blessed );

use Git::Repository;
use Git::FastExport::Block;

my $LF = "\012";

sub new {
    my ( $class, $handle ) = @_;
    return bless { stream => $handle }, $class;
}

sub next_block {
    my ($self) = @_;
    my $fh = $self->{stream};
    return if !defined $fh;

    my $block = bless {}, 'Git::FastExport::Block';

    # pick up the header from the previous round, or read it (first time)
    $self->{header} ||= <$fh>;
    $block->{header} = delete $self->{header};

    # nothing left to process
    return if !defined $block->{header};

    chomp $block->{header};
    ( $block->{type} ) = $block->{header} =~ /^(\w+)/g;

    local $_;
    while (<$fh>) {

        # we've reached the beginning of the next block
        if (/^(commit|tag|reset|blob|checkpoint|progress|feature|option|done)\b/) {
            s/^progress /progress [$self->{source}] / if exists $self->{source};
            $self->{header} = $_;
            last;
        }

        chomp;

        # special case of data block
        if (/^data (.*)/) {
            if ( substr( $1, 0, 2 ) eq '<<' ) {    # Delimited format

                # 'data' SP '<<' <delim> LF
                # <raw> LF
                # <delim> LF
                # LF?
                my $delim = substr( $1, 2 );
                local $/ = "$LF$delim$LF";
                chomp( $block->{data} = <$fh> );
            }
            else {                                 # Exact byte count format

                # 'data' SP <count> LF
                # <raw> LF?
                my $bytes = $1;
                if ($bytes) {
                    local $/ = \$bytes;
                    $block->{data} = <$fh>;
                }
                else {
                    $block->{data} = "";
                }
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

=head1 NAME

Git::FastExport - A parser for git fast-export streams

=head1 SYNOPSIS

    use Git::Repository;
    use Git::FastExport;

    # get the fast-export stream from a Git::Repository
    my $r  = Git::Repository->new();
    my $fh = $r->command(qw( fast-export --progress=1 --date-order --all ))->stdout;

    # create the parser object
    my $export = Git::FastExport->new($fh);

    # extract blocks from the fast-import stream
    while ( my $block = $export->next_block() ) {

        # do something with $block

    }

=head1 DESCRIPTION

Git::FastExport is a module that parses the output of
B<git-fast-export> and returns L<Git::FastExport::Block> objects that
can be inspected or modified before being eventually passed on as the
input to B<git-fast-import>.

=head1 METHODS

This class provides the following methods:

=head2 new

    my $export = Git::FastExport->new($fh);

The constructor takes an open filehandle and returns a
C<Git::FastExport> object attached to it.

=head2 next_block

    my $block = $export->next_block();

Returns the next block in the B<git-fast-export> stream as a
L<Git::FastExport::Block> object.

Return nothing at the end of stream.

This methods reads from the filehandle of the Git::FastExport object.

=head1 ACKNOWLEDGEMENTS

The original version of this module was created as part of my work
for BOOKING.COM, which authorized its publication/distribution
under the same terms as Perl itself.

=head1 AUTHOR

Philippe Bruhat (BooK) <book@cpan.org>

=head1 COPYRIGHT

Copyright 2008-2015 Philippe Bruhat (BooK), All Rights Reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
