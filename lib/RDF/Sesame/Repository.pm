# vim modeline vim600: set foldmethod=marker :

package RDF::Sesame::Repository;

use strict;
use warnings;

use Carp;

our $VERSION = '0.13';

=head1 NAME

RDF::Sesame::Repository - A repository on a Sesame server

=head1 DESCRIPTION

This class is the workhorse of RDF::Sesame.  Adding triples, removing triples
and querying the repository are all done through instances of this class.
Only SELECT queries are supported at this point, but it should be fairly
straightforward to add CONSTRUCT functionality.  If you do it, send me a
patch ;-)

=head1 METHODS

=head2 query_language ( [ $language ] )

Sets or gets the default query language.  Acceptable values for $language
are "RQL", "RDQL" and "SeRQL" (case sensitive).  If an unacceptable value
is given, query_language() behaves as if no C<$language> had been provided.

When an RDF::Sesame::Repository object is first created, the default query
language is SeRQL.  It is not necessary to change the default query language
because the language can be specified on a per query basis by using the 
C<$language> parameter of the select() method (documented below).

 Parameters :
    $language  The query language to use for queries in which the
        language is not otherwise specified.
 
 Returns :
    If setting, the old value is returned.  If getting, the current
    value is returned.
    
=cut

sub query_language {
    my $self = shift;

    $self->{errstr} = ''; # assume no errors

    return $self->{lang} unless defined $_[0];

    unless( $_[0]=~/^RQL|RDQL|SeRQL$/ ) {
        $self->{errstr} = Carp::shortmess("query language must be RQL, RDQL or SeRQL");
        return $self->{lang};
    }

    my $old = $self->{lang};

    $self->{lang} = $_[0];

    return $old;
}

=head2 select ( %opts )

Execute a query against this repository and return an RDF::Sesame::TableResult
object.  This object can be used to access the table of results in a number of
useful ways.

Only SELECT queries are supported through this method. A list of the options
which are currently understood is provided below.  If a single scalar is
provided instead of C<%opts>, the scalar is used as the value of the 'query'
option.

Returns an RDF::Sesame::TableResult on success or the empty string on failure.

If an error occurs, call errstr() for an explanation.

=head3 query

The text of the query to execute.  The format of this text is dependent on
the query language you're using.

Default: ''

=head3 language

The query language used by the query. The option accepts the same values as the query_language method.

If this option is not provided, the default language that was set through
query_language() is used.  If query_language() has not been called, then
"SeRQL" is assumed.

=head3 strip

Determines whether N-Triples encoding will be stripped from the
query results.  Normally, a literal is surrounded with double quotes and a
URIref is surrounded with angle brackets.  Literals may also have language
or datatype information.  By using the strip option, this behavior can be
changed.

The value of the strip option is a scalar describing how you want the
query results to be stripped.  Acceptable values are listed below.
The default for all calls to select may be changed by specifying the
strip option to RDF::Sesame::Connection::open

=over 4

=item B<literals>

strip N-Triples encoding from Literals

=item B<urirefs>

strip N-Triples encoding from URIrefs

=item B<all>

strip N-Triples encoding from Literals and URIrefs

=item B<none>

the default; leave N-Triples encoding intact

=back

For example, to strip all N-Triples encoding, call select() like this

 $repo->select(
    query => $serql,
    strip => 'all',
 );

=cut

sub select {
    my $self = shift;

    $self->{errstr} = ''; # assume no error

    # establish some sensible defaults
    my %defaults = (
        query    => '',
        language => $self->query_language,
        strip    => $self->{strip},
    );

    # get any options provided
    my %opts;
    if( @_ == 1 ) {
        $opts{query} = shift;
    } else {
        %opts = @_;
    }

    # set the defaults for any parameter we weren't given
    while( my ($k,$v) = each %defaults ) {
        $opts{$k} = $v unless exists $opts{$k};
    }

    my $r = $self->command(
        'evaluateTableQuery',
        {
            query         => $opts{query},
            queryLanguage => $opts{language},
            resultFormat  => 'xml',
        }
    );

    unless( $r->success ) {
        $self->{errstr} = Carp::shortmess($r->errstr);
        return '';
    }

    return RDF::Sesame::TableResult->new($r, strip => $opts{strip});
}

=head2 upload_data ( %opts )

Upload triples to the repository.  C<%opts> is a hash of named options
to use when uploading the data.  Acceptable option names are documented
below.  If a single scalar is provided instead of C<%opts>, the scalar
will be used as the value of the 'data' option.

This method is mostly useful for uploading triples which your program
has generated itself.  If you want to upload the data from a URI or even
a local file (using the "file:" URI scheme) then use the C<upload_uri>
method.  It will take care of fetching the data and uploading it all in
one step.

Returns the number of triples processed or 0 on error.  If an error
occurs during the upload, call errstr() to find out why.

=head3 data

The triples that should be uploaded.  The 'format' option specifies the
format of the triples.

Default: ''

=head3 format

The format of the 'data' option.  Acceptable values are 'rdfxml', 'ntriples'
and 'turtle'.  If a value other than these is specified, 0 is returned
and calling C<errstr> will return an explanatory message.

Default : ntriples

=head3 base

The base URI to use for resolving relative URIs.  The default is not useful so
be sure to specify this parameter if the data has relative URIs.

=head3 verify

Indicates whether data uploaded to Sesame should be verified before it is
added to the repository.

Default : true

=cut

sub upload_data {
    my $self = shift;

    $self->{errstr} = '';  # assume no error

    # establish some sensible defaults
    my %defaults = (
        data   => '',
        format => 'ntriples',
        verify => 1,
    );

    # set the defaults for any option we weren't given
    my %opts;
    if( @_ == 1 ) {
        $opts{data} = shift;
    } else {
        %opts = @_;
    }
    while( my ($k,$v) = each %defaults ) {
        $opts{$k} = $v unless exists $opts{$k};
    }

    # verify the format parameter
    if( $opts{format} !~ /^rdfxml|ntriples|turtle$/ ) {
        $self->{errstr} = Carp::shortmess("Format must be rdfxml, ntriples or turtle");
        return 0;
    }

    my $params = {
        data         => $opts{data},
        dataFormat   => $opts{format},
        verifyData   => $opts{verify} ? 'on' : 'off',
        resultFormat => 'xml',
    };

    # add in the base URI if we got it
    $params->{baseURI} = $opts{base} if exists $opts{base};

    my $r = $self->command( 'uploadData', $params );

    unless( $r->success ) {
        $self->{errstr} = Carp::shortmess($r->errstr);
        return 0;
    }

    foreach ( @{$r->parsed_xml->{status}} ) {
        if( $_->{msg} =~ /^Data is correct and contains (\d+) statement/ ) {
            return $1;
        }
        if( $_->{msg} =~ /^Processed (\d+) statement/ ) {
            return $1;
        }
    }

    $self->{errstr} = Carp::shortmess('Unknown error');
    return 0;
}

=head2 upload_uri ( %opts )

Uploads the triples from the resource located at a given URI.  This
method supports the "file:" URI scheme.  If a file URI is specified,
LWP::Simple is used to retrieve the contents of the URI.  Those contents
are then passed as the 'data' option to upload_data().  For any
URI scheme besides "file:", the Sesame server will retrieve the data on
its own.

The C<%opts> parameter provides a list of named options to use when uploading
the data.  If a single scalar is provided instead of C<%opts>, the scalar
is used as the value of the 'uri' option.  A list of acceptable options
is provided below.

Returns the number of triples processed or 0 on error.  If an error
occurs during the upload, call errstr() to find out why.

=head3 uri

The URI of the resource to upload.  The scheme of the URI may be 'file:' or
anything supported by Sesame.

Default: ''

=head3 format

The format of the data located at the given URI.  This can be one of 'rdfxml',
'ntriples' or 'turtle'.

Default: 'rdfxml'

=head3 base

The base URI of the data for resolving any relative URIs.  The default
base URI is the URI of the resource to upload.

=head3 verify

Indicates whether data uploaded to Sesame should be verified before it is
added to the repository.

Default : true

=cut

sub upload_uri {
    my $self = shift;

    $self->{errstr} = '';  # assume no error

    # set some sensible defaults
    my %defaults = (
        uri => '',
        format => 'rdfxml',
        verify => 1,
    );

    # set the defaults for any option we weren't given
    my %opts;
    if( @_ == 1 ) {
        $opts{uri} = shift;
    } else {
        %opts = @_;
    }
    while( my ($k,$v) = each %defaults ) {
        $opts{$k} = $v unless exists $opts{$k};
    }

    # set the default for the base URI
    $opts{base} = $opts{uri} unless exists $opts{base};

    # validate the format option
    if( $opts{format} !~ /^rdfxml|ntriples|turtle$/ ) {
        $self->{errstr} = Carp::shortmess("Format must be rdfxml, ntriples or turtle");
        return 0;
    }

    # handle the "file:" URI scheme
    if( $opts{uri} =~ /^file:/ ) {
        require LWP::Simple;
        my $content = LWP::Simple::get($opts{uri});
        unless( defined $content ) {
            $self->{errstr} = Carp::shortmess("No data in $opts{uri}");
            return 0;
        }

        delete $opts{uri};
        return $self->upload_data(
            data   => $content,
            %opts
        );
    }

    my $params = {
        url          => $opts{uri},
        dataFormat   => $opts{format},
        verifyData   => $opts{verify} ? 'on' : 'off',
        resultFormat => 'xml',
        baseURI      => $opts{base},
    };

    my $r = $self->command( 'uploadURL', $params );

    unless( $r->success ) {
        $self->{errstr} = Carp::shortmess($r->errstr);
        return 0;
    }

    foreach ( @{$r->parsed_xml->{status}} ) {
        if( $_->{msg} =~ /^Data is correct and contains (\d+) statement/ ) {
            return $1;
        }
        if( $_->{msg} =~ /^Processed (\d+) statement/ ) {
            return $1;
        }
    }

    $self->{errstr} = Carp::shortmess('Unknown error');
    return 0;
}

=head2 clear

Removes all triples from the repository.  When this method is finished, all
the data in the repository will be gone, so be careful.

 Return : 
    1 for success and the empty string for failure.

=cut

sub clear {
    my $self = shift;

    my $r = $self->command('clearRepository', { resultFormat => 'xml' });

    return '' unless $r->success;

    foreach ( @{ $r->parsed_xml->{status} } ) {
        if( $_->{msg} eq 'Repository cleared' ) {
            return 1;
        }
    }

    return 0;
}

=head2 remove ($subject, $predicate, $object)

Removes from the repository triples which match the specified pattern.
C<undef> is a wildcard which matches any value at that position.  For
example:

 $repo->remove(undef, "<http://xmlns.com/foaf/0.1/gender>", '"male"')

will remove from the repository all the foaf:gender triples which have a
value of "male".  Notice also that the values should be encoded in NTriples
syntax:

  * URI    : <http://foo.com/bar>
  * bNode  : _:nodeID
  * literal: "Hello", "Hello"@en and "Hello"^^<http://bar.com/foo>


 Parameters :
    $subject  The NTriples-encoded subject of the triples to
        remove.  If this is undef, it will match all
        subjects.
 
    $predicate  The NTriples-encoded predicate of the triples
        to remove.  If this is undef, it will match
        all predicates.
 
    $object  The NTriples-encoded object of the triples to remove.
        If this is undef, it will match all objects.
 
 Return : 
    The number of statements removed (including 0 on error).

=cut

sub remove {
    my $self = shift;

    # prepare the parameters for the command
    my $params = { resultFormat => 'xml' };
    $params->{subject}   = $_[0] if defined $_[0];
    $params->{predicate} = $_[1] if defined $_[1];
    $params->{object}    = $_[2] if defined $_[2];

    my $r = $self->command('removeStatements', $params);

    unless( $r->success ) {
        return 0;
    }

    foreach ( @{ $r->parsed_xml->{notification} } ) {
        if( $_->{msg} =~ /^Removed (\d+)/ ) {
            return $1;
        }
    }

    return 0;
}

=head2 errstr( )

Returns a string explaining the most recent error from this repository.
Returns the empty string if no error has occured yet or the most recent
method call succeeded.

=cut

sub errstr {
    my $self = shift;

    return $self->{errstr};
}

=head1 INTERNAL METHODS

These methods are used internally by RDF::Sesame::Repository.  They will
probably not be helpful to general users of the class, but they are
documented here just in case.

=head2 command ( $name [, $parameters ] )

Execute a command against a Sesame repository.  This method is generally
used internally, but is provided and documented in case others want to
use it for their own reasons.

It's a simple wrapper around the RDF::Sesame::Connection::command method
which simply adds the name of this repository to the list of parameters
before executing the command.


  Parameters :
    $name  The name of the command to execute.  This name should be
        the name used by Sesame.  Example commands are "login"
        or "listRepositories"
 
    $parameters  An optional hashref giving the names and values
        of parameters for the command.
 
  Return : 
    RDF::Sesame::Response

=cut

sub command {
    my $self = shift;

    $self->{conn}->command($self->{id}, $_[0], $_[1]);
}

# This method should really only be called from
# RDF::Sesame::Connection::open.
# As parameters, it takes an RDF::Sesame::Connection object and
# some named parameters
sub new {
    my $class = shift;
    my $conn  = shift;

    # prepare the options we were given
    my %opts;
    if( @_ == 1 ) {
        $opts{id} = shift;
    } else {
        %opts = @_;
    }
    return '' unless defined $opts{id};

    my $self = bless {
        id     => $opts{id}, # our repository ID
        conn   => $conn,     # a connection for accessing the server
        lang   => 'SeRQL',   # the default query language
        errstr => '',        # the most recent error string
        strip  => 'none',    # the default strip option for select()
    }, $class;

    if( exists $opts{query_language} ) {
        $self->query_language($opts{query_language});
    }

    $self->{strip} = $opts{strip} if exists $opts{strip};

    return $self;
}

return 1;
