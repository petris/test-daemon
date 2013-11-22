package Test::Daemon::Logger::TestSetSchedule;
use strict;
use Test::Daemon::Object;

our @ISA = qw(Test::Daemon::Object);
our @MANDATORY_ARGS = qw(filename);
our $VERSION = 0.01;

sub log_info($$$) {
	my ($self, $info, $files) = @_;

	$self->{testsets}{$info->{'Test::Daemon::TestCase::testset'}}{$info->{'Test::Daemon::TestCase::name'}} = $info;
}

sub testset_done {
	my $self = shift;
	my $testset = shift;

	my %times;

	while (my ($test, $info) = each %{$self->{testsets}{$testset}}) {
		my $started = $info->{'Test::Daemon::started'};
		my $completed = $info->{'Test::Daemon::completed'};

		foreach my $time ($started, $completed) {
			unless (defined $times{$time}) {
				$times{$time} = { started => [], completed => [] };
			}
		}
		push @{$times{$started}{started}}, $info;
		push @{$times{$completed}{completed}}, $info;
	}


	my $idx = 0;
	my @table;
	my @time_heading;
	my %running;
	my @free_rows = 0 .. 1024;
	foreach my $time (sort {$a <=> $b} keys %times) {
		push @time_heading, $time;
		my $process_finnished = sub {
			foreach my $info (@{$times{$time}{completed}}) {
				my $name = $info->{'Test::Daemon::TestCase::name'};
				if (defined $running{$name}) {
					my $ridx = $running{$name}{row};
					$running{$name}{span} = $idx - $running{$name}{idx};
					$running{$name}{end} = $idx;

					my $last_end = defined $table[$ridx][-1] ? $table[$ridx][-1]{end} : 0;
					if ($last_end < $running{$name}{idx}) {
						push @{$table[$ridx]}, { name => '', span => $running{$name}{idx} - $last_end, resource => '', desc => '' };
					}
					push @{$table[$ridx]}, $running{$name};
					unshift @free_rows, $running{$name}{row};
					delete $running{$name};
				}
			}
		};
		$process_finnished->();

		foreach my $info (@{$times{$time}{started}}) {
			my $name = $info->{'Test::Daemon::TestCase::name'};

			$running{$name}{row}      = shift @free_rows;
			$running{$name}{idx}      = $idx;
			$running{$name}{name}     = $info->{'Test::Daemon::TestCase::name'};
			$running{$name}{result}   = $info->{'Test::Daemon::result'};
			$running{$name}{resource} = $info->{'Test::Daemon::resources'};
			$running{$name}{desc}     = $info->{'Test::Daemon::TestCase::desc'};
			if (defined $self->{link_attr}) {
				$running{$name}{name_link}= $info->{$self->{link_attr}};
			}
		}

		$process_finnished->();

		$idx++;
	}

	my $filename = $self->{filename};
	$filename =~ s/%s/$testset/g;

	open OUT, '>', $filename;
	print OUT "<html>
	<head>
		<style type=\"text/css\">
			td.pass  { background: green; }
			td.fail  { background: red; }
			td.error { background: orange; }
			div.resources { font-size: xx-small; }
		</style>
		<title></title>
	</head>
		<body>
			<table>\n";

	print OUT "\t\t\t<tr>\n";
	foreach my $time (@time_heading) {
		my $start = $time - $time_heading[0];
		print OUT "\t\t\t\t<th>$start</th>\n";
	}
	print OUT "\t\t\t</tr>\n";

	foreach my $row (@table) {
		print OUT "\t\t\t<tr>\n";
		foreach my $cell (@$row) {
			my $class;

			unless (defined $cell->{result}) {
				$class = 'nop';
			} elsif ($cell->{result} == 0) {
				$class = 'pass';
			} elsif ($cell->{result} == 256) {
				$class = 'fail';
			} else {
				$class = 'error';
			}
			print OUT "\t\t\t\t<td class=\"$class\" colspan=\"$cell->{span}\">\n";
			if ($cell->{name_link}) {
				print OUT "\t\t\t\t\t<a href=\"$cell->{name_link}\">$cell->{name}</a><br>\n";
			} else {
				print OUT "\t\t\t\t\t$cell->{name}<br>\n";
			}
			print OUT "\t\t\t\t\t<div class=\"resources\">$cell->{resource}</div><div class=\"desc\">$cell->{desc}</div>\n";
			print OUT "\t\t\t\t</td>\n";
		}
		print OUT "\t\t\t</tr>\n";
	}
	print OUT "</table></body></html>\n";
	close OUT;

	delete $self->{testsets}{$testset};
}

1;

__END__

=head1 NAME

Test::Daemon::Logger::TestSetSchedule - Generate test schedule in html format 
for a test set

=head1 SYNOPSIS

Example configuration file segment:

   //   ...
   "loggers": [
      //   ...
      ["Test::Daemon::Logger::TestSetSchedule",
         {"filename": "${WORKSPACE}/results/TestSetSchedule.html", 
          "link_attr": "My::Deployment::TestRunner::out_file_name"}
      ],
      //   ...
   ],
   //   ...

=head1 INTRODUCTION

Test::Daemon::Logger::TestSetSchedule generates html file with tests schedule 
for every run testset (Test::Daemon::TestSet). The generated file is usefull
for debugging problems with parallel execution of testcases.

=head1 METHODS

=head2 new

New instance constructor with following arguments:

=over 4

=item filename (mandatory)

File name for generated html output.

=item link_attr (optional, default undef)

Name of attribute passed to the log_info method. Value of this attribute is
used as URL in a link from testcase name in generated html.

=back

=head2 testset_done

Executed by Test::Daemon::Runner when execution of a testset has finnished.

=head2 log_info

Executed by Test::Daemon::Runner after every run testcase.

=head1 SEE ALSO

L<Test::Daemon::Object> - Base class, allows reading constructor arguments from 
configuration file.

L<Test::Daemon::Runner> - Executes method of this objects.

L<Test::Daemon::TestSet> - Represents set of testcases.

=head1 AUTHOR

Petr Malat <oss@malat.biz>

=head1 COPYRIGHT

Copyright (c) 2011 - 2012 by Petr Malat E<lt>oss@malat.bizE<gt>

This program is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.
See F<http://www.perl.com/perl/misc/Artistic.html>.
