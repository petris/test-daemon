use 5.008001;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME              => 'Test::Daemon',
	VERSION_FROM      => 'lib/Test/Daemon.pm',
	#EXE_FILES         => ['bin/TestDaemon.pl', 'bin/tdps'],
	BUILD_REQUIRES    => {
		'Test::MockObject' => 1.09,
		'Test::Resub'      => 2.01,
		'Test::More'       => 0.98,
		'IPC::SysV'        => 2.03,
	},
	PREREQ_PM         => {
		'AnyEvent::Process' => 0.01,
		'AnyEvent'          => 7.02,
		'Coro'              => 6.10,
		'JSON'              => 2.03,
	},
	($] >= 5.005 ?     ## Add these new keywords supported since 5.005
		(ABSTRACT_FROM  => 'lib/Test/Daemon.pm',
			AUTHOR         => 'Petr Malat <oss@malat.biz>') : ()),
);
