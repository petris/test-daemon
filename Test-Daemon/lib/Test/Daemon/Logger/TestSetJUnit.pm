package Test::Daemon::Logger::TestSetJUnit;
use strict;

use File::Temp;
use POSIX qw(strftime);
use Test::Daemon::Common qw(get_file);
use Test::Daemon::Object;

our @ISA = qw(Test::Daemon::Object);
our @MANDATORY_ARGS = qw(filename);
our $VERSION = 0.01;
our @STREAMS = qw(out err);

sub testset_start($$$) {
	my ($self, $ts_name, $ts) = @_;

	$self->{testsets}{$ts_name} = {tests => scalar $ts->get_testcases(), errors => 0, failures => 0, timestamp => strftime('%Y-%m-%dT%H:%M:%S%z', localtime), start => time};

	return 0;
}

sub log_info($$$) {
	my ($self, $info, $files) = @_;
	my $testset = $info->{'Test::Daemon::TestCase::testset'};
	my $name = $info->{'Test::Daemon::TestCase::name'};

	# Skip tests, which were not executed
	if ($info->{'Test::Daemon::result'} != -1) {
		$self->{testsets}{$testset}{info}{$name} = $info;

		if ($info->{'Test::Daemon::result'} == 256) {
			$self->{testsets}{$testset}{failures}++;
		} elsif ($info->{'Test::Daemon::result'} != 0) {
			$self->{testsets}{$testset}{errors}++;
		}

		# Get stdout and stderr
		foreach my $stream (@STREAMS) {
			my $sn = 'system_' . $stream . '_file';
			if (defined $self->{$sn . '_attr'}) {
				my $file = $files . '/' . $info->{$self->{$sn . '_attr'}};
				if (-f $file) {
					$self->{testsets}{$testset}{info}{$name}{$sn} = get_file $file;
				}
			} elsif (defined $self->{'system_' . $stream . '_attr'}) {
				$self->{testsets}{$testset}{info}{$name}{$sn} = mktemp('TestDaemon-XXXXX');
				open OUT, '>', $self->{testsets}{$testset}{info}{$name}{$sn};
				print OUT $info->{$self->{'system_' . $stream . '_attr'}};
				close OUT;
			}
		}
	}
}

sub testset_done {
	my $self = shift;
	my $testset = shift;
	my $tsi = $self->{testsets}{$testset};
	my $time = time - $tsi->{start};
	my $filename = $self->{filename};

	$filename =~ s/%s/$testset/g;
	open OUT, '>', $filename;

	print OUT "<testsuite name=\"$testset\" tests=\"$tsi->{tests}\" failures=\"$tsi->{failures}\" errors=\"$tsi->{errors}\" timestamp=\"$tsi->{timestamp}\" hostname=\"localhost\" time=\"$time\">\n";
	print OUT "\t<properties>\n";
	print OUT "\t\t<property name=\"testset\" value=\"$testset\" />\n";
	print OUT "\t</properties>\n";
	while (my ($test, $info) = each %{$tsi->{info}}) {
		my $class = 'default';
		my $name  = $info->{'Test::Daemon::TestCase::name'} . ': ' . $info->{'Test::Daemon::TestCase::desc'};
		$time     = $info->{'Test::Daemon::time'};

		print OUT "\t<testcase classname=\"$class\" name=\"$name\" time=\"$time\">\n";
		my $msg = 'Testcase returned ' . $info->{'Test::Daemon::result'};

		# Add failure information if we failed
		if ($info->{'Test::Daemon::result'} == 256) {
			print OUT "\t\t<failure type=\"Does not returned 0\" message=\"$msg\">\n";
			print OUT "\t\t</failure>\n";
		} elsif ($info->{'Test::Daemon::result'} == 9) {
			print OUT "\t\t<error type=\"Killed\" message=\"$msg\">\n";
			print OUT "\t\t</error>\n";
		} elsif ($info->{'Test::Daemon::result'} != 0) {
			print OUT "\t\t<error type=\"Crashed or skipped\" message=\"$msg\">\n";
			print OUT "\t\t</error>\n";
		} 

		# Copy stdout and stderr
		foreach my $stream (@STREAMS) {
			my $sn = 'system_' . $stream . '_file';
			if (defined $info->{$sn}) {
				print OUT "\t\t<system-$stream><![CDATA[\n";
				if (open IN, '<', $info->{$sn}) {
					while (<IN>) { 
						print OUT map {/[[:print:]\n]/ ? $_ : sprintf "[0x%02x]", ord} split //;
					}
					close IN;
					unlink $info->{$sn};
				} else {
					print OUT "System-$stream file '$info->{$sn}' not found\n";
				}
				print OUT "\t\t]]></system-$stream>\n";
			}
		}

		print OUT "\t</testcase>\n";
	}
	print OUT "</testsuite>\n";
	close OUT;

	delete $self->{testsets}{$testset};

	return 0;
}

1;

__END__

=head1 NAME

Test::Daemon::Logger::TestSetJUnit - Generate JUnit results for a test set

=head1 SYNOPSIS

Example configuration file segment:

   //   ...
   "loggers": [
      //   ...
      ["Test::Daemon::Logger::TestSetJUnit",
         {"filename": "${WORKSPACE}/results/TestSetJUnit.xml", 
          "system_out_file_attr": "My::Deployment::TestRunner::out_file_name",
          "system_err_file_attr": "My::Deployment::TestRunner::err_file_name"}
      ],
      //   ...
   ],
   //   ...

=head1 INTRODUCTION

Test::Daemon::Logger::TestSetJUnit generates JUnit file for every run testset
(Test::Daemon::TestSet). The generated file is suitable for integrating 
Test::Daemon with other tools.

=head1 METHODS

=head2 new

New instance constructor with following arguments:

=over 4

=item filename (mandatory)

File name for generated JUnit output.

=item system_out_file_attr (optional, default undef)

Name of attribute passed to the log_info method, which contains file name of
standart output data. These data are copied to <system-out> node in JUnit file.

=item system_err_file_attr (optional, default undef)

Name of attribute passed to the log_info method, which contains file name of
standart error data. These data are copied to <system-err> node in JUnit file.

=back

=head2 testset_start

Executed by Test::Daemon::Runner when execution of a testset begins.

=head2 testset_done

Executed by Test::Daemon::Runner when execution of a testset has finnished.

=head2 log_info

Executed by Test::Daemon::Runner after every run testcase.

=head1 SEE ALSO

L<Test::Daemon::Object> - Base class, allows reading constructor arguments 
from configuration file.

L<Test::Daemon::Runner> - Executes method of this objects.

L<Test::Daemon::TestSet> - Represents set of testcases.

=head1 AUTHOR

Petr Malat <oss@malat.biz>

=head1 COPYRIGHT

Copyright (c) 2011 - 2012 by Petr Malat E<lt>oss@malat.bizE<gt>

This program is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.
See F<http://www.perl.com/perl/misc/Artistic.html>.
