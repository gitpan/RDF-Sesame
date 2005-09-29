use Module::Build;
# See perldoc Module::Build for details of how this works

my $build = Module::Build->new
    ( module_name     => 'RDF::Sesame',
      license         => 'perl',
      sign            => 1,
      requires        => {
          'Carp'           => 0,
          'Data::Table'    => 0,
          'LWP::UserAgent' => 0,
          'Test::More'     => 0.31,
          'URI'            => 0,
          'XML::Simple'    => 0,
      },
      create_makefile_pl => 'traditional',
    );

$build->create_build_script;
