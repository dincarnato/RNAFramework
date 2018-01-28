package Graphics::Object;

use strict;
use Core::Utils;
use Core::Mathematics qw(:all);
use POSIX;

use base qw(Data::XML);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ height    => 100,
                   fontsize  => 10,
                   _starty   => 0,
                   _xpadding => 0,
                   _margin   => 1/50,
                   _height   => undef,
                   _width    => undef }, \%parameters);
    
    $self->{heading} = 0;
    $self->_validate() if ($class =~ m/^Graphics::Object$/);
    
    return($self);
    
}

sub height { return($_[0]->{height}); }

sub _validate {
    
    my $self = shift;
    
    $self->SUPER::_validate();
    
    $self->throw("Height must be a positive integer > 0") if (!$self->{height} ||
                                                              !ispositive($self->{height}));
    $self->throw("Font size must be a positive integer > 0") if (!$self->{fontsize} ||
                                                                 !ispositive($self->{fontsize}));
    
}

sub _width {
    
    my $self = shift;
    my $width = shift if (@_);
    
    $self->throw("Method can be called only by a Graphics::Container object") unless((caller())[0] eq "Graphics::Container");
    
    if (defined $width) {
        
        $self->throw("Width must be a positive integer > 0") if (!ispositive($width) ||
                                                                 !$width);
    
        $self->{_width} = $width;
        $self->{_xpadding} = $self->{_margin} * $self->{_width};
    
    }
    
    return($self->{_width});
    
}

sub _height {
    
    my $self = shift;
    my $height = shift if (@_);
    
    $self->throw("Method can be called only by a Graphics::Container object") unless((caller())[0] eq "Graphics::Container");
    
    if (defined $height) {
        
        $self->throw("Height must be a positive integer > 0") if (!ispositive($height) ||
                                                                  !$height);
    
        $self->{_height} = $height;
    
    }
    
    return($self->{_height});
    
}

sub _starty {
    
    my $self = shift;
    my $y = shift if (@_);
    
    $self->throw("Method can be called only by a Graphics::Container object") unless((caller())[0] eq "Graphics::Container");
    
    if (defined $y) {
        
        $self->throw("Start Y coordinate must be an integer >= 0") if (!ispositive($y));
    
        $self->{_starty} = $y;
    
    }
    
    return($self->{_starty});
    
}

sub _xpadding {
    
    my $self = shift;
    my $padding = shift if (@_);
    
    $self->throw("Method can be called only by a Graphics::Container object") unless((caller())[0] eq "Graphics::Container");
    
    if (defined $padding) {
        
        $self->throw("Y padding must be an integer >= 0") if (!ispositive($padding));
    
        $self->{_xpadding} = $padding;
    
    }
    
    return($self->{_xpadding});
    
}

sub _textwidth {

    my $self = shift;
    my $text = shift if (@_);
    my $fontsize = shift || $self->{fontsize};
    
    # WX calculated using Font::AFM library and Helvetica.afm file (/usr/lib/afm/Helvetica.afm)
    my ($width, @wx);
    $width = 0;
    @wx = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
           278,278,355,556,556,889,667,222,333,333,389,584,278,584,278,278,
           556,556,556,556,556,556,556,556,556,556,278,278,584,584,584,556,
           1015,667,667,722,722,667,611,778,722,278,500,667,556,833,722,778,
           667,778,722,667,611,722,667,944,667,667,611,278,278,278,469,556,
           222,556,556,500,556,556,278,556,556,222,222,500,222,833,556,556,
           556,556,333,500,278,556,500,722,500,500,500,334,260,334,584,0,0,
           0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,278,333,333,333,333,333,333,333,333,
           0,333,333,0,333,333,333,278,333,556,556,556,556,260,556,333,737,
           370,556,584,333,737,333,400,584,333,333,333,556,537,278,333,333,
           365,556,834,834,834,611,667,667,667,667,667,667,1000,722,667,667,
           667,667,278,278,278,278,722,722,778,778,778,778,778,584,778,722,
           722,722,722,667,667,611,556,556,556,556,556,556,889,500,556,556,
           556,556,278,278,278,278,556,556,556,556,556,556,556,584,611,556,
           556,556,556,500,556,500);
    
    return(0) unless(length($text));
    
    $width += $wx[$_] for (unpack("C*", $text));
    $width *= $fontsize / 1000 if ($fontsize);
    
    return($width);
    
}

1;