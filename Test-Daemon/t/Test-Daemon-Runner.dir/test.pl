#!/usr/bin/env perl
use strict;
use IPC::SysV qw(IPC_CREAT IPC_EXCL S_IRUSR S_IWUSR);
use IPC::Msg;
use JSON;

# Open socket to comunicate with test master
exit -1 unless defined $ENV{MSG_KEY};
my $msg = IPC::Msg->new($ENV{MSG_KEY}, S_IRUSR | S_IWUSR) or die;

# Send information to test master
my %data = (
	file => $0,
	env  => \%ENV,
	args => \@ARGV,
	flag => ($$ - getppid) & 0x7F,
);
$data{flag} = 2 if $data{flag} < 2;

my $buf = to_json \%data;
$msg->snd(1, $buf);

# Receive reply from test master
$msg->rcv($buf, 256, $data{flag});

my $data = from_json $buf;
exit $data->{return};
