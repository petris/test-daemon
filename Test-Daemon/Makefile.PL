use 5.008001;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME              => 'Test::Daemon',
	VERSION_FROM      => 'lib/Test/Daemon/Runner.pm',
	#EXE_FILES         => ['bin/TestDaemon.pl', 'bin/tdps'],
	BUILD_REQUIRES    => {
		'Test::MockObject' => 1.20110612,
	},
	PREREQ_PM         => {
		'Test::Daemon::Object' => 0.01,
		'AnyEvent::Subprocess' => 1.102912,
		#'Getopt::Long' => 2.10,
		#'Pod::Usage' => 1.36,
		'File::Temp' => 0.20,
		'File::Copy' => 2.01,
		'File::Path' => 2.01,
		'Coro' => 5.372,
	},
	($] >= 5.005 ?     ## Add these new keywords supported since 5.005
		(ABSTRACT_FROM  => 'lib/Test/Daemon/Runner.pm',
			AUTHOR         => 'Petr Malat <oss@malat.biz>') : ()),
);
