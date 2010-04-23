#!/usr/bin/perl
use Data::Dumper;
=head1 NAME

gst-video-sample.pl - Embed a video in a Gtk2 window

=head1 SYNOPSIS

perl gst-video-sample.pl

=head1 DESCRIPTION

This program shows how to embed a video in a Gtk2 window. The window is created
by the program using Gtk2 and the video is decoded by Gstreamer. Both frameworks
are linked together in order to create a minimalist video player.

=head1 AUTHOR

Vala code from http://live.gnome.org/Vala/GStreamerSample ported to Perl.

=cut

use strict;
use warnings;

use Glib qw(TRUE FALSE);
use GStreamer '-init';
use GStreamer::Interfaces;
use Gtk2 '-init';

exit main();


sub main {
	# Create the main pipeline and GUI elements
	my ($pipeline, $sink) = create_pipeline();
	my ($window, $canvas, $buttons) = create_widgets();


	# Buttons used to control the playback
	add_button($buttons, 'gtk-media-play', sub {
		$sink->set_xwindow_id($canvas->window->get_xid);
		$pipeline->set_state('playing');
	});

	add_button($buttons, 'gtk-media-stop', sub {
		$pipeline->set_state('ready');
	});


	# Run the program
	Gtk2->main();

	# Cleanup
	$pipeline->set_state('null');
	return 0;
}


sub create_pipeline {
	my $pipeline = GStreamer::Pipeline->new('pipeline');

	# The pipeline's elements
	my ($src, $sink) = GStreamer::ElementFactory->make(
		videotestsrc => 'source',
		xvimagesink  => 'sink',
	);
  # my $caps = GStreamer::Caps->from_string( "video/x-raw-yuv, width=320, height=230" );
   my $caps = GStreamer::Caps::Simple -> new(
     	         "video/x-raw-yuv",
                 Width => "Glib::Int" => 320,
                 Height => "Glib::Int" => 240
	);
	print Dumper $caps;
	$pipeline->add($src, $caps, $sink);
	$src->link($sink);

	return ($pipeline, $sink);
}


sub create_widgets {
	# Create the widgets
	my $window = Gtk2::Window->new();
	$window->set_title("Gst video test");

	# This is where the video will be displayed
	my $canvas = Gtk2::DrawingArea->new();
	$canvas->set_size_request(300, 150);

	my $vbox = Gtk2::VBox->new(FALSE, 0);
	$vbox->pack_start($canvas, TRUE, TRUE, 0);

	# Prepare a box that will hold the playback controls
	my $buttons = Gtk2::HButtonBox->new();
	$vbox->pack_start($buttons, FALSE, TRUE, 0);

	$window->add($vbox);

	$window->signal_connect(delete_event => sub {
		Gtk2->main_quit();
		return Glib::SOURCE_CONTINUE;
	});
	$window->show_all();

	return ($window, $canvas, $buttons);
}


sub add_button {
	my ($box, $stock, $callback) = @_;
	my $button = Gtk2::Button->new_from_stock($stock);
	$button->signal_connect(clicked => $callback);
	$box->add($button);
	$button->show_all();
}
