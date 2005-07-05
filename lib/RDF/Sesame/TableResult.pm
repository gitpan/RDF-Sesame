package RDF::Sesame::TableResult;

use strict;
use warnings;

use base qw(Data::Table);

use Carp;

=head1 NAME

RDF::Sesame::TableResult - A class representing results from a select query

=head1 DESCRIPTION

The RDF::Sesame::Repository::select method returns a TableResult object
after completing a successful query.  This object is a subclass of
L<Data::Table> so many table manipulation methods are available.  Additional
methods specific to RDF::Sesame::TableResult are documented below.

The values returned by a query are represented in N-Triples syntax.  NULL
values are represented with C<undef>.

=head1 METHODS

=head2 has_rows( )

Returns a true value if the table result has any rows, otherwise it returns
a false value.  This method is a small wrapper around Data::Table::nofRow
to provide some syntactic sugar.

=cut

sub has_rows {
    my $self = shift;

    return $self->nofRow > 0;
}

=head2 sort( )

This method overrides the method provided by Data::Table.  The method
performs the same, but it allows for more pleasing parameter values.
For $type, one may pass the strings 'numeric' and 'non-numeric' instead of
0 and 1 respectively.  For $order, one may pass 'asc' and 'desc' instead
of 0 and 1 respectively.  The name parameters are case sensitive.

For further documentation, see L<Data::Table>.

=cut

sub sort {
    my ($self, @ps) = @_;

    my $i = 1;
    while( $i < $#_ ) {

        # munge the type parameter
        if( defined $ps[$i] ) {
            if( $ps[$i] eq 'numeric' ) {
                $ps[$i] = 0;
            } elsif( $ps[$i] eq 'non-numeric' ) {
                $ps[$i] = 1;
            }
        }

        $i++;

        # munge the order parameter
        if( defined $ps[$i] ) {
            if( $ps[$i] eq 'asc' ) {
                $ps[$i] = 0;
            } elsif( $ps[$i] eq 'desc' ) {
                $ps[$i] = 1;
            }
        }

        $i += 2;  # skip the next colID parameter
    }

    $self->SUPER::sort(@ps);
}

=head2 each( )

A method for iterating through the result rows, similar in spirit to
Perl's built-in each() function for hashes.  Returns a list consisting of
the values for the next row.  When all rows have been read, an empty list
is returned.  The next call to each() after that will start iterating again.

If you want to restart the iteration before reaching the end, see 
reset() which is documented below.  Here is an example:

 my $r = $repo->select($serql);
 while( my @row = $r->each ) {
    print join("\t", @row), "\n";
 }

=cut

sub each {
    my ($self) = @_;

    # have we passed the last row?
    if( $self->{coming} >= $self->nofRow ) {
        $self->{coming} = 0;
        return ();
    }

    # nope, so return the current row and increment our pointer
    return @{ $self->rowRef($self->{coming}++) };
}

=head2 reset( )

Reset the counter used by each() for iterating through the results.  Following
a call to reset() the next call to each() will return the values from the
first row of results.

=cut

sub reset {
    $_[0]->{coming} = 0;
}

#
# The $response parameter is an RDF::Sesame::Response object.
#
# This method is only intended to be called from RDF::Sesame::Repository
#
sub new {
    my ($class, $r, %opts) = @_;

    # make a copy of the header info for ourselves
    my @head = @{ $r->parsed_xml->{header}{columnName} };

    # set our 'strip_' values
    my $strip_literals = 0;
    my $strip_uris     = 0;
    if( defined $opts{strip} ) {
        $strip_literals = $opts{strip}=~/^literals|all$/;
        $strip_uris     = $opts{strip}=~/^urirefs|all$/;
    }

    # convert the tuples into our internal representation
    my @tuples;
    foreach my $t ( @{ $r->parsed_xml->{tuple} } ) {
        my @row = ();
        foreach my $a ( @{ $t->{attribute} } ) {
            my $content = $a->{content};

            # encode each type according to N-Triples syntax
            if( $a->{type} eq 'bNode' ) {
                push(@row, "_:$content");
            } elsif( $a->{type} eq 'uri' ) {
                if( $strip_uris ) {
                    push(@row, $content);
                } else {
                    push(@row, "<$content>");
                }
            } elsif( $a->{type} eq 'literal' ) {
                if( $strip_literals ) {
                    push(@row, $content);
                } elsif( $a->{'xml:lang'} ) {
                    push(@row, "\"$content\"\@" . $a->{'xml:lang'} );
                } elsif( $a->{datatype} ) {
                    push(@row, "\"$content\"^^<" . $a->{datatype} . ">" );
                } else {
                    push(@row, "\"$content\"" );
                }
            } else {
                # type must be 'null'
                push(@row, undef);
            }
        }

        push(@tuples, \@row);
    }

    my $self = $class->SUPER::new(\@tuples, \@head, 0);

    $self->{coming} = 0;  # the number of the next row for each()

    # reconsecrate ourselves and return
    return bless $self, $class;
}

=head1 AUTHOR

Michael Hendricks <michael@palmcluster.org>

=cut

return 1;
