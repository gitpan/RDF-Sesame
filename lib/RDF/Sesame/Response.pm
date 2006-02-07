package RDF::Sesame::Response;

use strict;
use warnings;
use XML::Simple;

our $VERSION = '0.13';

=head1 NAME

RDF::Sesame::Response - A response of a Sesame server to a command

=head1 DESCRIPTION

This class is mostly used internally, but it's documented here in case
others find use for it. This object contains information about the
response from the Sesame server and provides useful ways to access the
information.  After one executes RDF::Sesame::Connection::command or
RDF::Sesame::Repository::command, one should check the response object
to determine if the command was completed successfully.

Just to say it one more time, most users won't need this class.  Use
the methods provided by RDF::Sesame::Repository instead.

=head1 METHODS

=head3 success

Returns 1 if the response from the server indicates that the command
was completed successfully, otherwise it returns the empty string.

=cut

sub success {
    return $_[0]->{success};
}

=head3 errstr

Returns the error message provided by the Sesame server.  If there was no
error message, returns the empty string.

=cut

sub errstr {
    return $_[0]->{error};
}

=head3 xml

Returns the raw XML returned by the Sesame server.  This value will
only be available if the response actually included XML.  If it didn't,
the empty string will be returned.

=cut

sub xml {
    return $_[0]->{xml};
}

=head3 parsed_xml

Returns a hashref representation of the XML returned by the Sesame server.
If no XML is available, returns an empty hashref.  XML::Simple is used
to parse the XML.

=cut

sub parsed_xml {
    return $_[0]->{parsed};
}

=head3 http_response

Returns the HTTP::Response object representing the original HTTP response
from the server.  This allows one access to the lower-level details about
the response.

=cut

sub http_response {
    return $_[0]->{http};
}

#
# Creates a new RDF::Sesame::Response object.
#
# The parameter $response is an HTTP::Response object
#

sub new {
    my ($class, $r) = @_;

    my $self = bless {
        http    => $r, # our original HTTP::Response object
        success => 0,  # was the command sucessful?
        xml     => '', # the XML from the server
        error   => '', # the error message from the server
        parsed  => {}, # a hashref representing the parsed XML
    }, $class;

    # return an empty object if we got no HTTP::Response
    return $self unless $r;

    if( $r->is_success ) {
        $self->{success} = 1;
        my $xml = $r->content;
        $self->{xml} = $xml;

        # check for an actual XML response
        if( $r->header('Content-Type') =~ m#text/xml# ) {
            # because the XML for tuples prevents XML::Simple
            # from retaining the attribute order, we do a transform
            # to improve the XML.
            # See the documentation for _fix_tuple()

            $xml =~ s#<tuple>(.*?)</tuple>#_fix_tuple($1)#siegx;

            # TODO call a custom XML::SAX parser instead
            $self->{parsed} = XMLin(
                $xml,
                ForceArray => [
                    qw(repository status notification
                       columnName tuple  attribute  
                       error                         )
                ],
                KeyAttr    => [ ],
            );
        }

        # examine the XML for error responses
        if( exists $self->{parsed}{error} ) {
            $self->{success} = 0;
            $self->{error} = @{$self->{parsed}{error}}[0]->{msg};
        }
    } else {
        $self->{error} = $r->message;
    }

    return $self;
}

# The XML returned by Sesame after evaluating a table query
# contains the attributes of each tuple in the same order as
# the attribute (column) names.  This order is not preserved by XML::Simple
# so we need to transform the provided-XML into a more useful form.
# This could be done with XSLT but that's overkill, so
# we jut use regular expressions.
#
# An example transform would take XML like this
#
# <tuple>
#   <bNode>node1</bNode>
#   <literal>Hello</literal>
#   <uri>http://example.com</uri>
#   <literal datatype="http://example.org/string">World!</literal>
# </tuple>
#
# and transform it into XML like this
#
# <tuple>
#   <attribute type='bNode'>node1</attribute>
#   <attribute type='literal'>Hello</attribute>
#   <attribute type='uri'>http://example.com</attribute>
#   <attribute type='literal' datatype="http://example.org/string">World!</attribute>
# </tuple>
sub _fix_tuple {
    my $content = shift;

    $content =~ s#
        <\s*(bNode|literal|uri)(.*?)>(.*?)</\1>
       #<attribute type='$1'$2>$3</attribute>#sgix;

    $content =~ s#
        <\s*(null)(.*?)\s*/\s*>
       #<attribute type='$1'$2 />#sgix;

    return "<tuple>$content</tuple>";
}


=head1 AUTHOR

Michael Hendricks <michael@palmcluster.org>

=cut

return 1;
