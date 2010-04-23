#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;
use Glib qw{ TRUE FALSE };
use Gtk2 '-init';
use Gnome2;
use GStreamer qw(GST_SECOND GST_TIME_FORMAT GST_TIME_ARGS);
use Data::Dumper;
use DBI;
use subs qw{ main on_window_destroy };
use Gtk2::Ex::Simple::List; # Needed?
use Gtk2::Ex::Simple::Tree; #needs packaging
use File::Find::Rule;
use Date::Format;
use MP3::Tag;


 my	($builder, $window, $gst, $dbh, $pos, $dur, $main_tree);
 my $version = 0.1;
 my $dbargs = {AutoCommit => 1, PrintError => 1};
 my $dbdir = "$ENV{HOME}/.spambox";
 my $dbfile = "sb.db.sqlite";  
sub tidy_up {
 $dbh->disconnect;
 warn "Spambox closing, Bye!\n";
 $gst->set_state('null');
 Gtk2->main_quit;
#my $dialog = Gtk2::Dialog->new ('Byebye!', $window,
#                                    'destroy-with-parent',
#                                    'gtk-ok' => 'none');
# my $label = Gtk2::Label->new ('Thanks');
# $dialog->get_content_area ()->add ($label);
# $dialog->signal_connect (response => sub { $_[0]->destroy });
# $dialog->show_all;
}

sub update_state {
 my ($temp, $state, $temp2) = $gst->get_state(1);
 my $btn = $builder->get_object( 'playbutton' );
 if ($state  =~ "paused") {
   $btn->set_label("Play");}
 else{
  $btn->set_label("Pause");}
}
sub on_message {
 my ($bus, $message, $loop) = @_;
 if ($message->type == 'state-changed') {update_state()}
 elsif ($message->type == 'tag') {}#print Dumper ($message->tag_list)
 elsif ($message -> type == 'error') {warn $message -> error}
 elsif ($message->type == 'duration') {}#TODO
 elsif ($message->type == 'async-done') {}#TODO
 elsif ($message->type == 'eos') {}#TODO
 elsif ($message->type == 'new-clock') {}#TODO
 elsif ($message->type == 'stream-status') {}#Useless - indicates Gstreamer streams
 else {warn "Unknown GStreamer bus message type - " . $message->type}
 get_position();
 return TRUE;
}
sub on_sync_message {
 warn "Sync message recieved\n"; #TODO connect sync messages - requires threads
}

sub on_filechooserbutton1_file_set {
 my $self=shift;
 my $file = $self->get_filename;
 load_file($file);
}

sub on_playbutton_clicked {
 my $self=shift;
 my ($temp, $state, $temp2) = $gst->get_state(1);
 if ($state  =~ "playing") {
   $gst -> set_state("paused");
   $self->set_label("Play");}
 else{
  $gst -> set_state("playing");
  $self->set_label("Pause");}
 get_position();
}
sub load_file {
  if (my $file=shift) {
   if ( -f $file) {
    print "Loading " . $file ."\n";
    $gst->set_state('null');
    $gst = GStreamer::ElementFactory -> make("playbin", "play",);
    $gst->set(uri => Glib::filename_to_uri $file, "localhost");
    $gst->get_bus()->add_signal_watch;
    $gst->get_bus()->signal_connect("message", \&on_message);
    $gst->get_bus()->signal_connect("sync-message", \&on_sync_message);
    $gst->set_state('playing');
   }
  }
}
sub create_gst_pipeline {
 $gst = GStreamer::ElementFactory -> make("playbin", "play",);
 if (my $file = shift) {
  if (-f $file) {
   my $fcb = $builder->get_object( 'filechooserbutton1');
   $fcb->set_filename($file);
   load_file($file);
  }
 else {warn "Usage: $0 filename_to_autoload\nRecieved argument $file discarded\n"}
 }
}
sub load_window {
 $builder = Gtk2::Builder->new();
 $builder->add_from_file( 'Main.glade' );
 $window = $builder->get_object( 'window1' );
 $builder->connect_signals( undef );
 $window->show();
}
sub get_position {
 my $pos_query = GStreamer::Query::Position -> new("time");
 my $dur_query = GStreamer::Query::Duration -> new("time");
 if ( $gst->query($pos_query) && $gst->query($dur_query)) {
  my $pos_ns = $pos_query->position;
  my $dur_ns = $dur_query->duration;
  $pos = nsec_to_sec($pos_ns);
  $dur = nsec_to_sec($dur_ns);
  my $statusbar = $builder->get_object( 'statusbar1' );
  my $string = sprintf "%" . GST_TIME_FORMAT . " / %" . GST_TIME_FORMAT . "\r",
           GST_TIME_ARGS(($pos_query -> position)[1]),
           GST_TIME_ARGS(($dur_query -> duration)[1]);
  $statusbar->push(0, $string);
  my $hscale = $builder->get_object( 'hscale1' );
  $hscale->set_range(0,$dur_ns);
  $hscale->set_value($pos_ns);
 }
}
sub on_hscale1_change_value () {
 my ($self, $type, $new_pos) = @_;
 $new_pos = int($new_pos);
 #warn "Slider Moved to $new_pos\n";
 if (1) { #TODO if playing - should test if playing and change GST_SEEK_FLAG_FLUSH
 #TODO do something with buffer status
 $gst->seek(1, "GST_FORMAT_TIME", "GST_SEEK_FLAG_FLUSH", "GST_SEEK_TYPE_SET", $new_pos,
                         "GST_SEEK_TYPE_NONE", "GST_CLOCK_TIME_NONE");
 }
 return FALSE;
}
sub nsec_to_sec () {
 my $ns = shift;
 return int($ns/1000000000); 
}
sub on_window1_destroy {
  tidy_up();
}
sub init_main_tree {
  my $stree = Gtk2::Ex::Simple::Tree->new_from_treeview (
                $builder->get_object ('treeview1'), 'Spambox'    => 'text',);
    @{$stree->{data}} = (
        { value => [ 'Now Playing'] },
		{ value =>['Music'],
				children =>[{value =>['All Music'],},
					{value=>['Search']},
					{value=>['Playlists']}]
		},
  );
}

sub init_main_list {
  $main_tree = Gtk2::Ex::Simple::List->new_from_treeview (
                    $builder->get_object ('treeview2'), #TODO change name of builder to gtkbuilder or glade
                    'Filename'    => 'text',
                    'Created'     => 'text',
                    'Modified'  => 'text', );
  push @{$main_tree->{data}}, ["My file", 'date', 'datey'];
  $main_tree->show;
}
sub init_db {
 if (not -d $dbdir) {mkdir "$dbdir" or warn "Err: $? - Could not create $dbdir directory in home folder - Please check permissions"}
 if (not -f "$dbdir/$dbfile") {warn "Creating new database...\n"}
 #TODO - check for sqlite driver and warn
 $dbh = DBI->connect("dbi:SQLite:dbname=$dbdir/$dbfile","","") or warn "Could not open database";
    if ($dbh->err()) { warn "$DBI::errstr\n"; }
 init_conf();
}
sub on_button_update_db_clicked {#TODO Thread/separate jobs
	my $root = get_conf('Library_Folder');
	warn "Updating db folder $root\n";
	$dbh->do("DROP TABLE Music"); #TODO error handle if no table yet, check on startup if db empty
	$dbh->do ( "CREATE TABLE Music (File, Size, Accessed, Modified)");
	#TODO - VFS?
	if (-d $root) {#find files
		#find (\&file_wanted, $root);
		my @files = File::Find::Rule->file->in($root);
		warn "Found " . ($#files +1) . " Files, processing...\n";
		foreach (@files) {
			my $file = $_;
			my @stat = stat($file);
			#warn "$file @stat"; #7=>size 8=>atime 9=>mtime 10=>ctime (ctime not creation time
			#my $size = sprintf("%.2f", ($stat[7]/1000000) );
			#my $atime = time2str("%X %x", $stat[8]);
			#warn "Size $size MB, Accessed $atime";
			$dbh->do("INSERT INTO Music VALUES (\"$file\", $stat[7], $stat[8], $stat[9])");
			#warn "INSERT INTO Music VALUES (\"$file\", $stat[7], $stat[8], $stat[9])";
			my $tag = MP3::Tag->new($file);
			$tag->get_tags();
			if (exists ($tag->{ID3v2})){
					my $artist = $tag->{ID3v2}->artist;
					my $album = $tag->{ID3v2}->album;
					
					warn "TAGLIB - $artist\n";
			
		}
	}
	my @items = $dbh->selectall_arrayref("SELECT Size FROM Music" );
	warn (($#items +1) . " items in music library\n");
  }
  else {warn "Could not access Library Folder: $root\n";}
}
#TODO think about splitting gstreamer / gtk into separate processes/threads
#sub file_wanted {print $File::Find::name . "\n"; push (@files, $File::Find::name);};
sub init_conf {
 my $result = $dbh->selectall_arrayref("SELECT * FROM Configuration WHERE Key = 'Version'" );
 if ($DBI::errstr || not $result->[0]) {
  warn "Recreating Configuration Database" .$DBI::errstr . "\n";
  $dbh->do ( "CREATE TABLE Configuration (Key, Value)");
  $dbh->do("INSERT INTO Configuration VALUES (\"Version\", \"$version\")");
 }
 $result = $dbh->selectall_arrayref("SELECT * FROM Configuration WHERE Key = 'Version'" );
 my ($key, $value) = $result->[0];
 warn "Spambox version $version, database version $$key[1].\n";
}
sub get_conf {
 my $key = shift;
 my $value = $dbh->selectrow_array ( "SELECT Value FROM Configuration WHERE Key = \"$key\"" );
 return $value;
}
sub set_conf {
 my ($key, $value) = @_;
 if (get_conf($key)){$dbh->do("UPDATE Configuration SET Value = \"$value\" WHERE Key = \"$key\"");}
else {$dbh->do("INSERT INTO Configuration VALUES (\"$key\", \"$value\")")}
 
}
sub exit_db {
  $dbh-> disconnect
}
sub run_prefs {
 warn "Run Prefs\n";
 $builder->add_from_file( 'Preferences.glade' );
 my $prefs = $builder->get_object( 'preferences_window' );
 $builder->connect_signals( undef );
 $prefs->show();
 my $fcb = $builder->get_object( 'folder_chooser' );
 my $folder = get_conf('Library_Folder');
 if ($folder && -d $folder) {$fcb->set_current_folder($folder)}
}
sub on_folder_chooser_selection_changed {
 my $self=shift;
 my $folder = $self->get_filename;
 warn "Changing Library Folder to $folder\n";
 set_conf('Library_Folder', $folder);
}
sub run_about (){
 my $about = Gnome2::About->new ('Spambox', $version, 'Copyright Sam Brookfield, 2010', 'Comments to sbrookfield@gmail.com', 'Sam Brookfield', undef, undef, undef);
 $about->show_all();
}
sub main {
 init_db();
 GStreamer->init;
 load_window();
 init_main_tree(); init_main_list();
 create_gst_pipeline(shift);
 Gtk2->main();
}
main(shift);
exit(0);
 #my $temp = $builder->get_object( 'filechooserbutton1' );
 #my $file = $temp->get_filename;
   #print Dumper $gst->get_bus;
   #$gst-> get_bus()-> add_watch(\&on_message);
#my $get_conf_sql = $dbh->prepare ( "SELECT Value FROM Configuration WHERE Key = ?" );
 #$get_conf_sql->execute($key);
 #my $value = $get_conf_sql->fetchrow_array();
 #my $query = GStreamer::Query::Duration->new ("time");
 #$query->duration("time",23);
 #print $dumper->dumpValue( $query);
# $main_tree = Gtk2::Ex::Simple::List->new_from_treeview (
#                    $builder->get_object ('treeview1'), #TODO change name of builder to gtkbuilder or glade
#                    'Filename'    => 'text',
#                    'Created'     => 'text',
# #                 'Modified'  => 'text', );
#push @{$main_tree->{data}}, ["My file", 'date', 'datey'];
# $main_tree->show;
