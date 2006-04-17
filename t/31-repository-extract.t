use strict;
use warnings;
use Test::More;

use RDF::Sesame;

plan tests => 6;

SKIP: {

    # do we have all that's needed to run this test?
    my $uri    = $ENV{SESAME_URI};
    my $r_name = $ENV{SESAME_REPO};
    skip 'SESAME_URI environment not set', 6  unless $uri;
    skip 'SESAME_REPO environment not set', 6 unless $r_name;
    eval "use Test::RDF";
    skip "Test::RDF needed for testing repository dump", 6 if $@;

    my $conn = RDF::Sesame->connect( uri => $uri );
    my $repo = $conn->open($r_name);
    $repo->clear();  # make sure it's empty
    $repo->upload_uri( 'file:t/dc.rdf' );

    # try a simple extraction
    {
        my $rdf = $repo->extract( format => 'ntriples' );
        rdf_eq(
            ntriples => \$rdf,
            rdfxml   => 't/dc.rdf',
            'extract to scalar return value',
        );
    }

    # try extraction to a filehandle
    {
        my $rdf;
        open my $fh, '>', \$rdf;
        $repo->extract(
            format => 'turtle',
            output => $fh,
        );
        close $fh;
        rdf_eq(
            turtle => \$rdf,
            rdfxml => 't/dc.rdf',
            'extract to a filehandle',
        );
    }

    # try extraction to a named file
    SKIP: {
        eval "use File::Temp";
        skip "File::Temp needed for testing repository dump to file", 1
            if $@;

        my ($fh, $filename) = File::Temp::tempfile();
        close $fh;
        $repo->extract(
            format => 'rdfxml',
            compress => 'none',  # explicitly set no compression
            output => $filename,
        );
        rdf_eq(
            rdfxml => $filename,
            rdfxml => 't/dc.rdf',
            'extract to a filename',
        );
    }

    # pseudo-compress the RDF as it's extracted
    {
        my $rdf = $repo->extract(
            format => 'turtle',
            compress => {
                init => sub {
                    my ($fh) = @_;
                    print $fh 'init.';
                    my $context = 1;
                    return \$context;
                },
                content => sub {
                    my ($context, $fh, $content) = @_;
                    if ( $$context ) {
                        print $fh 'content.';
                        $$context = 0;
                    }
                },
                finish => sub {
                    my ($context, $fh) = @_;
                    print $fh 'finish.';
                },
            },
        );
        is( $rdf, 'init.content.finish.', '"compression" worked' );
    }

    # try some error conditions
    eval { $repo->extract() };
    like( $@, qr/No serialization format specified/, 'no extract format' );

    ok($repo->clear, 'clearing repository');
}
