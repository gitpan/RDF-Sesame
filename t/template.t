# This is an empty test file that should be used
# as a template for creating more tests

use warnings;
use strict;

use Test::More tests => 3;

BEGIN { use_ok('RDF::Sesame'); }

SKIP: {
    skip 'SESAME_URI environment not set', 2  unless $ENV{SESAME_URI};
    skip 'SESAME_REPO environment not set', 2 unless $ENV{SESAME_REPO};

    my $conn = RDF::Sesame->connect( uri => $ENV{SESAME_URI} );

    die "No connection: $RDF::Sesame::errstr\n" unless defined($conn);
    isa_ok($conn, 'RDF::Sesame::Connection', 'connection');

    my $repo = $conn->open($ENV{SESAME_REPO});
    isa_ok($repo, 'RDF::Sesame::Repository', 'repository');


    # make sure there's no old data in there
    $repo->clear;

    $repo->upload_uri( 'file:t/dc.rdf' );

    # Put your tests here and run them against the DC
    # schema that the test just uploaded to the repository

    # don't leave our junk lying around
    $repo->clear;

}

