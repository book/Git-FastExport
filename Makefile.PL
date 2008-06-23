use ExtUtils::MakeMaker;
WriteMakefile(
    PL_FILES     => {},
    NAME         => 'Git::FastExport',
    EXE_FILES    => [ 'script/git-merge-repos', ],
    VERSION_FROM => 'lib/Git/FastExport.pm',
    PREREQ_PM    => { 'Git' => 0.01, },
    LICENSE      => 'perl',
);

