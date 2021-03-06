package CMMS::Zone::Sender;

use strict;
use CMMS::Zone::NowPlaying;
use CMMS::Zone::Library;
use CMMS::Zone::Player;
use CMMS::Zone::Command;
use Quantor::Log;

our $permitted = {
	mysqlConnection => 1,
	verbose         => 1,
	logfile         => 1
};
our($AUTOLOAD);

#############################################################
# Constructor
#
sub new {
	my $class = shift;
	my (%params) = @_;

	die('No database connection') unless $params{mc};
	die('No config') unless $params{conf};
	die('No handle') unless $params{handle};
	die('No zone') unless $params{zone};

	my $self = {};
	$self->{conf} = $params{conf};
	$self->{handle} = $params{handle};
	$self->{zone} = $params{zone};

	$self->{library} = new CMMS::Zone::Library(mc => $params{mc}, handle => $self->{handle}, zone => $self->{zone}, conf => $self->{conf});
	$self->{now_playing} = new CMMS::Zone::NowPlaying(mc => $params{mc}, handle => $self->{handle}, zone => $self->{zone}, conf => $self->{conf});

	bless $self, $class;
	$self->mysqlConnection($params{mc});

	return $self;
}

#############################################################
# AUTOLOAD restrict method aliases
#
sub AUTOLOAD {
	my $self = shift;
	die("$self is not an object") unless my $type = ref($self);
	my $name = $AUTOLOAD;
	$name =~ s/.*://;

	die("Can't access '$name' field in object of class $type") unless( exists $permitted->{$name} );

	return (@_?$self->{$name} = shift:$self->{$name});
}

#############################################################
# DESTROY
#
sub DESTROY {
	my $self = shift;
}

sub loop { 
	my $self = shift;

	my $line;
	my %cmd;

	while(1) {
		sysread(STDIN,$line,1024);
		$line =~ s/\r+//g;

		foreach my $command (split "\n", $line) {
			qlog INFO, "Received command: $command\n";
			%cmd = cmd2hash $command;
			next unless %cmd;  # empty hash - there won't be command either
			next unless &check_cmd(\%cmd, $self->{zone}->{number}); # do further checking (eg. zone)
			my $cmd = $self->process(\%cmd);
			send2player($self->{handle}, $cmd) if $cmd;
		}
	}
}

sub process {
	my($self,$c) = @_;

	if ($self->{lc $c->{screen}}) {  # Call function
	    my $screen = lc $c->{screen};
	    return eval "\$self->{$screen}->process(\$c)";
	} else {
	    qlog WARNING, "Unknown screen: $c->{screen}";
	}

	return 0;
}

1;
