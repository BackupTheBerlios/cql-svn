#!/usr/bin/perl -w

=head1 COPYLEFT

 $Id: cqld.pl,v 3 2004/10/16 00:35:27 pr0gm4 Exp $

 This file is part of CQL - Configuration Query Language
 Copyright (C) 2004 by Jan Gehring <jfried@linoratix.com>

 CQL is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 CQL is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with CQL; if not, write to the Free Software Foundation, Inc.,
 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

=cut

use IO::Socket;
use strict;
use Symbol;
use POSIX;
use Data::Dumper;

=head1 NAME

CQL TCP-Server

=head1 DESCRIPTION

 This is the CQL Server 

=head1 USAGE

Start it with 

# perl cqld.pl

=cut


#
# this must be configurable later
#
my $PREFORK			= 5;
my $MAX_CLIENTS_PER_CHILD	= 5;
my %children			= ();
my $children			= 0;

#
# generating server object
#
my $server = IO::Socket::INET->new(
		LocalPort	=> 2345,
		Type		=> SOCK_STREAM,
		Proto		=> 'tcp',
		Reuse		=> 1,
		Listen		=> 10
	) or &error($!,1);

=head2 REAPER()

cares for ended childs

=cut
sub REAPER {
	$SIG{CHLD} = \&REAPER;
	my $pid = wait;
	$children --;
	delete $children{$pid};
}

=head2 HUNTSMAN()

quit all child processes

=cut
sub HUNTSMAN {
	local ($SIG{CHLD}) = 'IGNORE';
	kill 'INT'	=> keys %children;
	exit;
}

sub make_new_child {
	my $pid;
	my $sigset;
	my $client;
	my $data;
	my $rv;
	
	$sigset = POSIX::SigSet->new(SIGINT);
	sigprocmask(SIG_BLOCK, $sigset) or &error("Kann SIGINT fuer fork nich blockieren: $!",1);

	&error("fork: $!", 1) unless defined ($pid = fork);
	
	if($pid) {
		sigprocmask(SIG_UNBLOCK, $sigset) or &error("Kann SIGINT fuer fork nicht entsperren: $!", 1);
		$children{$pid} = 1;
		$children++;
		return;
	} else {
		$SIG{INT} = 'DEFAULT';
		
		sigprocmask(SIG_UNBLOCK, $sigset) or &error("Kann SIGINT fuer fork nicht entsperren: $!",1);
		
		for(my $i = 0; $i < $MAX_CLIENTS_PER_CHILD; $i++) {
			$client = $server->accept() or last;
			while(&work_with_data($client)) {
			}
		}
		
		exit;
	}
}

sub work_with_data {
	my $client = $_[0];
	my $data = "";
	my $rv = $client->recv($data, POSIX::BUFSIZ, 0);

	chomp($data);

	if($data =~ m/exit/) {
		close($client);
		return 0;
	}
	
	my $answer = interpret($data);

	$rv = $client->send("$answer\n", 0);
	return 1;
}

=head2 interpret()

this function interprets the client data

@param string

=cut
sub interpret($)
{
	# uebergabe holen
	my $param = shift;
	# die befehle aufsplitten
	# hier muss drauf geachtet werden, dass nur - .'te verwendet werden die nicht in '...' stehen
	my @commands = split(/;(?=[^']*(?:'[^']*'[^']*)*$)/, $param);
	
	return Dumper(@commands);
}

sub error {
	print STDOUT "\n-------------------------\n";
	print STDOUT "[" .localtime(time) . "] Fehler: " . $_[0] ;
	
	if($_[1] eq "1") {
		print STDOUT "\nSchwerwiegend ... breche Programm ab !";
	}
	print STDOUT "\n-------------------------\n";
	if($_[1] eq "1") {
		exit 1;
	}	
}

#
# prefork the stuff
#
for(1 .. $PREFORK) {
	make_new_child();
}


#
# signal handlers
#
$SIG{CHLD} = \&REAPER;
$SIG{INT}  = \&HUNTSMAN;

#
# and here we're forking us to background
#
my $pid = fork;
exit if $pid;

POSIX::setsid() or &error("Konnte keine neue session starten: $!",1);

my $time_to_die = 0;

sub signal_handler {
	$time_to_die = 1;
	&HUNTSMAN;
}

$SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signal_handler;

until ($time_to_die) {
	sleep;
	for(my $i = $children; $i < $PREFORK; $i++) {
		&make_new_child();
	}
}


