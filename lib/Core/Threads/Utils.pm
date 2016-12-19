package Core::Threads::Utils;

use strict;
use Cwd;
use threads::shared;

our $cwd = cwd();  #our per thread cwd, init on startup from cwd
our $cwd_mutex : shared; # the variable we use to sync
our $Cwd_cwd = \&Cwd::cwd;

*Cwd::cwd = *threadsafe_cwd;     

sub threadsafe_cwd {
    
    lock($cwd_mutex);
    CORE::chdir($cwd);
    $Cwd_cwd->(@_);

}

*CORE::GLOBAL::chdir = sub {
         
    lock($cwd_mutex);
    CORE::chdir($_[0]) || return undef;
    $cwd = $Cwd_cwd->();

};

1;