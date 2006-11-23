#!/usr/bin/perl -w

use strict;
use CMMS::File;
use CMMS::Ripper;
use CMMS::Track::Enhanced;
use Audio::TagLib;
use Digest::MD5 qw(md5_hex);
use Getopt::Long;
use POSIX qw(setsid);
use Encode qw(encode_utf8);

my($child);
GetOptions(child => \$child);

my $ripper = new CMMS::Ripper(
	nocache => 1,
	conf => '/etc/cmms.conf'
);

my $fsizes = {};
if($child) {
	while(1) {
		import_folder('/usr/local/cmms/htdocs/import/',1);
		sleep(2);
	}
} else {
	# let's fork to the background like a proper daemon

	# disconnect from terminals
	open STDIN, '/dev/null' if -t STDIN;
	open STDERR, '>/dev/null' if -t STDERR;
	open STDOUT, '>/dev/null' if -t STDOUT;

	# move off any unmountable filesystems
	chdir '/';

	my $pid=fork();

	if($pid) {
		# fork worked and we're the parent
		exit 0;
	} elsif(not defined $pid) {
		# fork failed - I guess we'll just live with it...
		print STDERR "$0 failed to fork to the background\n";
	} else {
		# we are the forked child
		setsid() or die("$0 failed to get a new session");
	}

	while(1) {
		system($0.' -child');
		sleep 2;
		print STDERR "Restarting...\n";
	}
}

sub import_folder {
	my($folder,$root) = @_;
	$folder =~ s|/$||;

	if(my @files  = grep{/\.(mp3|flac)$/i} <$folder/*>) {
		my $trck_num = 0;
		foreach my $file (@files) {
			my($album,$year);
			my $imports = [];
			my $tracks  = [];
			my($ext) = ($file =~ /\.(mp3|flac)$/i);
			$trck_num++;
			if(!exists($fsizes->{$file})) {
				$fsizes->{$file} = {size=>-s $file,time=>time};
				next;
			} elsif($fsizes->{$file}->{size} ne -s $file) {
				$fsizes->{$file}->{size} = -s $file;
				$fsizes->{$file}->{time} = time;
				next;
			} elsif($fsizes->{$file}->{time}+10 > time) {
				next;
			}
			my $track = new CMMS::Track::Enhanced;
			$track->type(lc($ext));
			print STDERR "File [$file]\n";
			my $meta = undef;
			if($file =~ /\.flac$/i) {
				my $flac = new Audio::TagLib::FLAC::File($file);
				next unless $flac->audioProperties;
				$track->length($flac->audioProperties->length);

				 if(my $id32 = $flac->ID3v2Tag) {
					$meta = 1;
					print STDERR "File [$file] has metadata [ID3v2Tag]\n";
					$track->title(cleanupmeta($id32->title->toCString?$id32->title->toCString:'Unknown'));
					$track->artist(cleanupmeta($id32->artist->toCString?$id32->artist->toCString:'Unknown'));
					$track->number(($id32->track?$id32->track:$trck_num));
					$track->genre(cleanupmeta($id32->genre->toCString?$id32->genre->toCString:'Unknown'));
					$album = cleanupmeta($id32->album->toCString?$id32->album->toCString:'Unknow');
					$year  = $id32->year;
				} elsif(my $id3 = $flac->ID3v1Tag) {
					$meta = 1;
					print STDERR "File [$file] has metadata [ID3v1Tag]\n";
					$track->title(cleanupmeta($id3->title->toCString?$id3->title->toCString:'Unknown'));
					$track->artist(cleanupmeta($id3->artist->toCString?$id3->artist->toCString:'Unknown'));
					$track->number(($id3->track?$id3->track:$trck_num));
					$track->genre(cleanupmeta($id3->genre->toCString?$id3->genre->toCString:'Unknown'));
					$album = cleanupmeta($id3->album->toCString?$id3->album->toCString:'Unknow');
					$year  = $id3->year;
				} elsif(my $xiph = $flac->xiphComment) {
					$meta = 1;
					print STDERR "File [$file] has metadata [XiphComment]\n";
					$track->title(cleanupmeta($xiph->title->toCString?$xiph->title->toCString:'Unknown'));
					$track->artist(cleanupmeta($xiph->artist->toCString?$xiph->artist->toCString:'Unknown'));
					$track->number(($xiph->track?$xiph->track:$trck_num));
					$track->genre(cleanupmeta($xiph->genre->toCString?$xiph->genre->toCString:'Unknown'));
					$album = cleanupmeta($xiph->album->toCString?$xiph->album->toCString:'Unknown');
					$year  = $xiph->year;
				}
			} elsif($file =~ /\.mp3$/i) {
				my $mp3 = new Audio::TagLib::MPEG::File($file);
				$track->length($mp3->audioProperties->length);

 				if(my $id32 = $mp3->ID3v2Tag) {
					$meta = 1;
					print STDERR "File [$file] has metadata [ID3v2Tag]\n";
					$track->title(cleanupmeta($id32->title->toCString?$id32->title->toCString:'Unknown'));
					$track->artist(cleanupmeta($id32->artist->toCString?$id32->artist->toCString:'Unknown'));
					$track->number(($id32->track?$id32->track:$trck_num));
					$track->genre(cleanupmeta($id32->genre->toCString?$id32->genre->toCString:'Unknown'));
					$album = cleanupmeta($id32->album->toCString?$id32->album->toCString:'Unknow');
					$year  = $id32->year;
				} elsif(my $id3 = $mp3->ID3v1Tag) {
					$meta = 1;
					print STDERR "File [$file] has metadata [ID3v1Tag]\n";
					$track->title(cleanupmeta($id3->title->toCString?$id3->title->toCString:'Unknown'));
					$track->artist(cleanupmeta($id3->artist->toCString?$id3->artist->toCString:'Unknown'));
					$track->number(($id3->track?$id3->track:$trck_num));
					$track->genre(cleanupmeta($id3->genre->toCString?$id3->genre->toCString:'Unknown'));
					$album = cleanupmeta($id3->album->toCString?$id3->album->toCString:'Unknown');
					$year  = $id3->year;
				}
			}

			$file =~ s/(\W)/\\$1/g;
			$file =~ s|\\/|/|g;

			if(defined $meta) {
				push @{$tracks}, $track;
				push @{$imports}, $file;
			} else {
				print STDERR "track ($trck_num) [$file] has no meta data\n";
				($_) = ($file =~ m@/([^/]+\.(mp3|flac))$@i);
				s/\\//g;
				system('mkdir -p /usr/local/cmms/htdocs/import/failed/') unless -d '/usr/local/cmms/htdocs/import/failed/';
				if(!-f '/usr/local/cmms/htdocs/import/failed/'.$_) {
					system("mv $file /usr/local/cmms/htdocs/import/failed/");
				} else {
					system("rm -f $file");
				}
			}

			if($album) {
				my $discid = md5_hex(lc($tracks->[0]->artist.' '.$album));
				my $metadata = {
					GENRE     => $tracks->[0]->genre,
					DISCID    => $discid,
					discid    => $discid,
					ARTIST    => $tracks->[0]->artist,
					ALBUM     => $album,
					COMMENT   => '',
					COMPOSER  => '',
					CONDUCTOR => '',
					YEAR      => $year,
					TRACKS    => $tracks
				};

				if($ripper->check($metadata)) {
					my $newlocation = safe_chars($tracks->[0]->artist).'/'.safe_chars($album);
					system("mkdir -m 777 -p /usr/local/cmms/htdocs/media/$newlocation/") unless -d "/usr/local/cmms/htdocs/media/$newlocation/";
					my $i=0;
					foreach my $file (@{$imports}) {
						my $track = $tracks->[$i++];
						my($xt) = ($file =~ /\.(mp3|flac)$/i);
						my $number = sprintf '%02d', $track->number;
						my $newname = substr(safe_chars($number.' '.$track->title),0,35).'.'.lc($xt);
						system("cp $file /usr/local/cmms/htdocs/media/$newlocation/$newname") unless -f "/usr/local/cmms/htdocs/media/$newlocation/$newname";
						system("chown nobody:nobody /usr/local/cmms/htdocs/media/$newlocation/$newname") if -f "/usr/local/cmms/htdocs/media/$newlocation/$newname";
						system("rm -f $file");
					}

					$ripper->cover($metadata);
					$ripper->store($metadata);
				} else {
					warn "Album [$discid] [$album] already ripped";
					foreach my $file (@{$imports}) {
						system("rm -f $file");
					}
				}
				delete $fsizes->{$file};
			}
		}
	}

	my $del = 1;
	if(@_=grep{!/^\.+$/}<$folder/*>) {
		foreach(@_) {
			$del = 0 if -d $_ || $_ =~ /\.(mp3|flac)$/i;
		}

		foreach my $fld (grep{!/\/failed/}@_) {
			my $nfld = $fld;
			$nfld =~ s/(\W)/\\$1/g;
			$nfld =~ s|\\/|/|g;
			import_folder($nfld) if -d $fld;
		}
	}
	system("rm -fR $folder/") if !($folder =~ m|/failed|) && $del;
}

sub cleanupmeta {
	my $str = encode_utf8(shift);

	$str =~ s/[\r\n]/ /g;
	$str =~ s/\s+/ /g;
	$str =~ s/^\s+//g;
	$str =~ s/\s+$//g;

	return $str;
}
