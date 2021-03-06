package CMMS::Ripper::Encoder::lame;

use strict;
use warnings;
use base qw(CMMS::Ripper::Encoder::Generic);
use CMMS::Psudo;
use CMMS::File;
use Audio::TagLib;
use POSIX qw(:sys_wait_h);

sub _encode {
	my($self,$number,$track,$artist,$album,$comment,$year,$genre,$aartist) = @_;
	($number,$track,$artist,$album,$comment,$year,$genre,$aartist) = map{s/[\r\n+]//g;$_}($number,$track,$artist,$album,$comment,$year,$genre,$aartist);

	$artist = 'Unknown' if $artist =~ /^unknown/i;

	$self->{status}->set(data => 'MP3 Encoding '.sprintf('%02d',$number));
	print STDERR 'MP3 Encoding track '.sprintf('%02d',$number)."\n";

	my $file = substr(safe_chars(sprintf('%02d',$number)." $track"),0,35);
	my $tmp = $self->{conf}->{ripper}->{tmpdir};

	print STDERR "$tmp$file.mp3\n";

	my($LAME,$pid) = psudo_tty("nice -n 10 lame -b 160 $tmp$file.wav $tmp$file.mp3 2>&1");

	my($oprog,$orate) = ('','44.1 kHz 160 kbps');
	$self->{setings}->set(data => $orate);

	while(sysread $LAME,$_,250) {
		if(/
      \d+\/\d+\s+     # 300 6288   
	\(\s*(\d+)%\)	# ( 5%)           $1
	\|\s*\d+\:\d+	# CPU time
	\/\s*\d+\:\d+	# CPU time estim
	\|\s*\d+\:\d+	# REAL time
	\/\s*\d+\:\d+	# REAL time estim
	\|\s*(\d+\.\d+x)# play CPU        $2
	\|\s*(\d+:\d+)	# ETA             $3
      /x) {
        		my $prog = sprintf("%3s%%  %s  %s", $1, $2, $3);
			if($oprog ne $prog) {
				$self->{detail}->set(data => $prog);
				$oprog = $prog;
			}
		}

		if(/([0-9\.]+ kHz [0-9]+ kbps)/ || /([0-9\.]+ kHz VBR\(q=[0-9]+\))/) {
			my $rate = $1;
			if($orate ne $rate) {
				$self->{setings}->set(data => $rate);
				print STDERR "$rate\n";
				$orate = $rate;
			}
		}

		if(/\.done/) {
			$self->{status}->set(data => 'Encoding done');
			print STDERR "Encoding done\n";
			last;
		}

		if(/Could not find/) {
			$self->{status}->set(data => 'Encoding error');
			print STDERR "Encoding error: $_\n";
			`rm -f $tmp$file.mp3` if -f "$tmp$file.mp3";
			last;
		}
	}

	kill 9, $pid;
	close($LAME);
	waitpid $pid, 0;

	if(-f "$tmp$file.mp3") {
		my($artist1,$album1,$track1) = map{s/"/\\"/g;$_}($artist,$album,$track);

		my $mp3   = new Audio::TagLib::MPEG::File("$tmp$file.mp3");
		my $id3v2 = $mp3->ID3v2Tag(1);

		$id3v2->setAlbum(new Audio::TagLib::String($album1))   if $album;
		$id3v2->setArtist(new Audio::TagLib::String($artist1)) if $artist;
		$id3v2->setTitle(new Audio::TagLib::String($track1))   if $track;
		$id3v2->setTrack($number)                              if $number;
		$id3v2->setYear(new Audio::TagLib::String($year))      if $year;
		$id3v2->setGenre(new Audio::TagLib::String($genre))    if $genre;

		$mp3->save;

		$aartist = safe_chars($aartist);
		$album = safe_chars($album);

		my $folder = $self->{conf}->{ripper}->{mediadir}."$aartist/$album/";

		`mkdir -p $folder` unless -d $folder;
		`mv $tmp$file.mp3 $folder`;
		`chown nobody:nobody $folder$file.mp3` if -f "$folder$file.mp3";
		print STDERR "mv $tmp$file.mp3 $folder\n";
	}

	return 1;
}

1;
