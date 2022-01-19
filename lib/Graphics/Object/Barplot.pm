package Graphics::Object::Barplot;

use strict;
use Core::Utils;
use Core::Mathematics qw(:all);
use POSIX;

use base qw(Graphics::Object::Yaxis);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    # Since certain parameters can be both SCALAR or ARRAY, we adjust them here
    $parameters{barfill} = [$parameters{barfill}] if (ref($parameters{barfill}) ne "ARRAY");
    $parameters{barstroke} = [$parameters{barstroke}] if (ref($parameters{barstroke}) ne "ARRAY");
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ barstroke       => [],
                   barfill         => ["grey"],
                   _barwidth       => 0,
                   _barspace       => 0 }, \%parameters);

    $self->SUPER::_validate();
    
    return($self);
    
}

sub _calcplotwidth {
    
    my $self = shift;
    
    my ($minwidth, $plotarea, $div) = (0, 0, 0);
    $minwidth = $self->{_xpadding} + $self->{_margin} * $self->{_width};
    $plotarea = $self->{_width} - $minwidth;
    $div = 0.25 * $#{$self->{values}} + @{$self->{values}};
    $self->{_barwidth} = $plotarea / $div;
    $self->{_barspace} = $self->{_barwidth} * 0.25;
    
    $self->warn("Image width is too small (Required: " . ceil($minwidth) . "px)") if ($minwidth >= $self->{_width});
    
}

sub _barwidth { return($_[0]->{_barwidth}); }

sub _plotdata {
    
    my $self = shift;
    
    my ($lastx, $baseline, @heights, @bfill,
        @bstroke);
    $lastx = $self->{_xpadding};
    $baseline = maprange(@{$self->{yrange}}, @{$self->{_yarea}}, abs($self->{_baseline}));
    @heights = map { maprange(@{$self->{yrange}}, @{$self->{_yarea}}, abs($_)) - $baseline } @{$self->{values}};
    @bfill = @{$self->{barfill}};
    @bfill = (@bfill, ($self->{barfill}->[-1]) x (@heights - @{$self->{barfill}}));
    @bstroke = (@{$self->{barstroke}}, ($self->{barstroke}->[-1]) x (@heights - @{$self->{barstroke}}));
    
    for (0 .. $#heights) {
        
        $self->emptytag("rect", { x              => $lastx,
                                  y              => $self->_vertalign(max($self->{_baseline}, $self->{values}->[$_])),
                                  width          => $self->{_barwidth},
                                  height         => $heights[$_],
                                  fill           => $heights[$_] ? $bfill[$_] || "grey" : "none", # No fill on bars with height = 0
                                  stroke         => $heights[$_] ? $bstroke[$_] || "" : "none",   # No fill on bars with height = 0
                                  "fill-opacity" => $self->{opacity},
                                  style          => "stroke-width:" . min(1, 0.90 * ($self->{_barspace} / 2)) . ";" });
        $lastx += $self->{_barwidth} + $self->{_barspace};
        
    }
    
}

sub _plotxaxis {
    
    my $self = shift;
    
    if (my @labels = @{$self->{labels}}) {
    
        my $lastx = $self->{_xpadding} + 1/2 * $self->{_barwidth};
        @labels = @{$self->{labels}};
        
        for (0 .. $#labels) {
            
            $self->tagline("text", $labels[$_], { style                => "font-size: " . $self->{fontsize} . "px; font-family: Helvetica;",
                                                  "text-anchor"        => $self->{labelrotate} ? "end" : "middle",
                                                  "alignment-baseline" => "middle",
                                                  "dominant-baseline"  => "mathematical",
                                                  transform            => "translate(" . join(",", $lastx, $self->{_yarea}->[1] + $self->{_labelspace} + $self->{fontsize} / 2) . ") rotate(" . -abs($self->{labelrotate}) . ")" });
            
            $lastx += $self->{_barwidth} + $self->{_barspace};
            
        }
    
    }
    
    if ($self->{xname}) {
        
        $self->tagline("text", $self->{xname}, { "text-anchor" => "middle",
                                                 style         => "font-size: " . $self->{fontsize} . "px; font-family: Helvetica;",
                                                 x             => mean($self->{_xpadding}, $self->{_width} - $self->{_width} * $self->{_margin}),
                                                 y             => $self->{_starty} + $self->{_height} - 1/2 * $self->{fontsize} });
        
    }
    
}

sub _plotstdev {
    
    my $self = shift;
    
    my ($lastx, @y1, @y2);
    $lastx = $self->{_xpadding} + 1/2 * $self->{_barwidth};
    @y1 = map { $self->_vertalign($_) } @{$self->{_values}->[0]};
    @y2 = map { $self->_vertalign($_) } @{$self->{_values}->[1]};
    
    for (0 .. $#y1) {
        
        $self->emptytag("line", { x1     => $lastx,
                                  x2     => $lastx,
                                  y1     => $y1[$_],
                                  y2     => $y2[$_],
                                  stroke => "black",
                                  style  => "stroke-width:" . min(1, 0.05 * $self->{_barwidth}) . ";" });
        
        $lastx += $self->{_barwidth} + $self->{_barspace};
        
    }
    
}

1;
