#!/usr/bin/perl

package RF::Utils;

use strict;
use Core::Utils;
use Graphics::Image;

use base qw(Exporter);

our @EXPORT = qw(checkRinstall);

sub checkRinstall {

    my $R = shift || $ENV{"RF_RPATH"} || which("R");

    Graphics::Image->new( R             => $R,
                          checkPackages => 1 );

    return($R);

}

1;