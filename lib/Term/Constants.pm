package Term::Constants;

use strict;

use base qw(Exporter);

our %EXPORT_TAGS = ( colors => [ qw(RESET BOLD UNDERLINE BLINK
                                    BLACK RED GREEN YELLOW
                                    BLUE MAGENTA CYAN WHITE
                                    BBLACK BRED BGREEN BYELLOW
                                    BBLUE BMAGENTA BCYAN BWHITE) ],
                     screen => [ qw(RLADD RLRESET CLRALL CLRROW
                                    CURTOP RET CLRTOP CLRRET) ] );

{ my (%seen);
  push(@{$EXPORT_TAGS{all}}, grep {!$seen{$_}++} @{$EXPORT_TAGS{$_}}) foreach (keys %EXPORT_TAGS); }

our @EXPORT_OK = ( @{$EXPORT_TAGS{colors}},
                   @{$EXPORT_TAGS{screen}} );

use constant RESET     => "\e[0m";
use constant BOLD      => "\e[1m";
use constant UNDERLINE => "\e[4m";
use constant BLINK     => "\e[5m";
use constant BLACK     => "\e[30m";
use constant RED       => "\e[31m";
use constant GREEN     => "\e[32m";
use constant YELLOW    => "\e[33m";
use constant BLUE      => "\e[34m";
use constant MAGENTA   => "\e[35m";
use constant CYAN      => "\e[36m";
use constant WHITE     => "\e[37m";
use constant BBLACK    => "\e[90m";
use constant BRED      => "\e[91m";
use constant BGREEN    => "\e[92m";
use constant BYELLOW   => "\e[93m";
use constant BBLUE     => "\e[94m";
use constant BMAGENTA  => "\e[95m";
use constant BCYAN     => "\e[96m";
use constant BWHITE    => "\e[97m";

use constant RLADD     => "\001";
use constant RLRESET   => "\002";
use constant CLRALL    => "\e[2J";
use constant CLRROW    => "\e[2K";
use constant CURTOP    => "\e[0;0H";
use constant RET       => "\r";
use constant CLRTOP    => CLRALL . CURTOP;
use constant CLRRET    => CLRROW . RET;

1;