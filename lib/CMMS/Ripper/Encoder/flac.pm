package CMMS::Ripper::Encoder::flac;

use strict;
use warnings;
use base qw(CMMS::Ripper::Encoder::Generic);
use CMMS::Psudo;
use CMMS::File;

sub _encode {
	my($self,$number,$track,$artist,$album,$comment,$year,$genre,$aartist) = @_;
	($number,$track,$artist,$album,$comment,$year,$genre,$aartist) = map{s/[\r\n+]//g;$_}($number,$track,$artist,$album,$comment,$year,$genre,$aartist);

	$artist = 'Unknown' if $artist =~ /^unknown/i;

	$self->{status}->set(data => 'Flac Encoding '.sprintf('%02d',$number));
	print STDERR 'Flac Encoding track '.sprintf('%02d',$number)."\n";

	my $file = safe_chars(sprintf('%02d',$number)." $artist $track");
	my $tmp = $self->{conf}->{ripper}->{tmpdir};

	print STDERR "$tmp$file.flac\n";

	my($FLAC,$pid) = psudo_tty("flac $tmp$file.wav -o $tmp$file.flac 2>&1");

	my $oprog = '';
	$self->{setings}->set(data => (length($track)>20?substr($track,0,20):$track));

	while(1) {
		sysread $FLAC,$_,100;

		if(/.+: ([0-9]+)% complete, ratio=([0-9\.]+)/) {
        		my $prog = sprintf("%3s%%  %s", $1, $2);
			if($oprog ne $prog) {
				$self->{detail}->set(data => $prog);
				$oprog = $prog;
			}
		}

		if(/wrote/) {
			$self->{status}->set(data => 'Encoding done');
			print STDERR "Encoding done\n";
			last;
		}

		if(/can't open input file/) {
			$self->{status}->set(data => 'Encoding error');
			print STDERR "Encoding error: $_\n";
			last;
		}
	}

	close($FLAC);
	kill 9, $pid;

	$aartist = safe_chars($aartist);
	$album = safe_chars($album);
	$comment = substr(safe_chars($comment),0,32);

	my $folder = $self->{conf}->{ripper}->{mediadir}."$aartist/$album/";
	$folder .= "$comment/" if $comment;

	`mkdir -p $folder` unless -d $folder;
	`mv $tmp$file.flac $folder` if -f "$tmp$file.flac";
	print STDERR "mv $tmp$file.flac $folder\n";

	return 1;
}

1;
