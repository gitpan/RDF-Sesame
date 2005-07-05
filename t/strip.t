use warnings;
use strict;

use Test::More tests => 6;

BEGIN { use_ok('RDF::Sesame'); }

SKIP: {
    my $uri    = $ENV{SESAME_URI};
    my $r_name = $ENV{SESAME_REPO};
    skip 'SESAME_URI environment not set', 5  unless $uri;
    skip 'SESAME_REPO environment not set', 5 unless $r_name;

    my $conn = RDF::Sesame->connect( uri => $uri );

    die "No connection: $RDF::Sesame::errstr\n" unless defined($conn);

    my $repo = $conn->open($r_name);

    # make sure there's no old data in there
    $repo->clear;

    $repo->upload_uri( 'file:t/dc.rdf' );

    my $serql = <<"";
        SELECT uri, literal
        FROM {dc:title} uri            {"1999-07-02"};
                        dcterms:issued {literal}
        USING NAMESPACE
            dc = <http://purl.org/dc/elements/1.1/>,
            dcterms = <http://purl.org/dc/terms/>

    ###### Verify the behavior of the 'strip' option

    ### default
    my $res = $repo->select($serql);
    my @row = $res->each;
    is_deeply(
        \@row,
        [ '<http://purl.org/dc/terms/issued>', '"1999-07-02"' ],
        'default'
    );

    ### literals
    $res = $repo->select( query=>$serql, strip=>'literals' );
    ok( eq_array(
            [ $res->each ],
            [ '<http://purl.org/dc/terms/issued>', '1999-07-02' ]
        ),
        'literals'
    );

    ### urirefs
    $res = $repo->select( query=>$serql, strip=>'urirefs' );
    ok( eq_array(
            [ $res->each ],
            [ 'http://purl.org/dc/terms/issued', '"1999-07-02"' ]
        ),
        'urirefs'
    );

    ### urirefs
    $res = $repo->select( query=>$serql, strip=>'all' );
    ok( eq_array(
            [ $res->each ],
            [ 'http://purl.org/dc/terms/issued', '1999-07-02' ]
        ),
        'all'
    );

    ###### Verify setting the default for strip

    $repo = $conn->open( id => $r_name, strip => 'all');
    $res = $repo->select($serql);
    ok( eq_array(
            [ $res->each ],
            [ 'http://purl.org/dc/terms/issued', '1999-07-02' ]
        ),
        'setting default through open()'
    );



    # don't leave our junk lying around
    $repo->clear;
}

