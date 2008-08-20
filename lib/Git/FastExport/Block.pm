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

'progress 1 objects';

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

__END__
