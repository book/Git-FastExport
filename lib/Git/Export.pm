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
        'git fast-export --progress=1 HEAD' )
        or die "Can't git fast-export on $repo: $!";
    chdir $cwd or die "Can't chdir back to $cwd: $!";

    return $self->{pid};
}

sub next_block {
    my ($self) = @_;
    my $block = bless { raw => [] }, 'Git::Export::Block';
    my $fh = $self->{out};

    # use the header from last time, or read it (first time)
    $self->{header} ||= <$fh>;
    ( $block->{type} ) = $self->{header} =~ /^(\w+)/g;
    push @{ $block->{raw} }, \"$self->{header}";

    while (<$fh>) {

        # we've reached the end
        if (/^(commit|tag|reset|blob|checkpoint|progress)\b/) {
            $self->{header} = $_;
            last;
        }
        push @{ $block->{raw} }, \"$_";

        # special case of data block
        if (/^data (\d+)/) {
            local $/ = \"$1";
            $block->{data} = <$fh>;
        }
        elsif( /^(\w+)/) {
            push @{ $block->{$1} }, $block->{raw}[-1];
        }
        else {
            # ignore empty lines, but choke on others
            die "Unexpected line:\n$_\n" if !/^$/;
        }
    }

    return $block;
}

package Git::Export::Block;

sub as_string {
    my ($self) = @_;
    return join '',
        map { $$_ =~ /^data / ? ( $$_, $self->{data} ) : $$_ }
        @{ $self->{raw} };
}

1;

