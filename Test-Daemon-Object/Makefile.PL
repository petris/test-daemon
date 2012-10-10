use 5.008001;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Test::Daemon::Object',
    VERSION_FROM      => 'lib/Test/Daemon/Object.pm',
    PREREQ_PM         => {JSON => 2.50, Carp => 1.04}, 
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Test/Daemon/Object.pm', 
       AUTHOR         => 'Petr Malat <oss@malat.biz>') : ()),
);
