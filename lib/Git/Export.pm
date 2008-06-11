package Git::Export;
use strict;
use warnings;
use Cwd;
use IPC::Open2;

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub fast_export {
    my ( $self, $repo ) = @_;
    $self->{source} = $repo;

    my $cwd = getcwd;
    chdir $repo or die "Can't chdir to $repo: $!";
    $self->{pid}
        = open2( $self->{out}, $self->{in},
        'git fast-export --progress=1 --all' )
        or die "Can't git fast-export on $repo: $!";
    chdir $cwd or die "Can't chdir back to $cwd: $!";

    return $self->{pid};
}

sub next_block {
    my ($self) = @_;
    my $block = bless {}, 'Git::Export::Block';
    my $fh = $self->{out};

    return if eof $fh;

    # use the header from last time, or read it (first time)
    $block->{header} = $self->{header} ||= <$fh>;
    chomp $block->{header};
    ( $block->{type} ) = $block->{header} =~ /^(\w+)/g;

    local $_;
    while (<$fh>) {

        # we've reached the beginning of the next block
        if (/^(commit|tag|reset|blob|checkpoint|progress)\b/) {
            $self->{header} = $_;
            last;
        }

        chomp;

        # special case of data block
        if (/^data (\d+)/) {
            local $/ = \"$1";
            $block->{data} = <$fh>;
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

package Git::Export::Block;

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

