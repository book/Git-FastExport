use Module::Build;
my $build = Module::Build->new(
    module_name    => 'Git::FastExport',
    license        => 'perl',
    requires       => { 'Git' => 0.01, },
    script_files   => [ glob 'script/*' ],
    add_to_cleanup => ['Git-FastExport-*'],
);
$build->create_build_script();

