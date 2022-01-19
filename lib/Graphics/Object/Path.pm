package Graphics::Object::Path;

use strict;
use Core::Utils;
use Core::Mathematics qw(:all);
use POSIX;

use base qw(Graphics::Object::Yaxis);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ plotpoints      => 0,
                   pointfill       => "black",
                   stroke          => "black",
                   fill            => "none",
                   _pointdist      => 0 }, \%parameters);

    $self->_validate();
    
    return($self);
    
}

sub _validate {
    
    my $self = shift;
    
    $self->SUPER::_validate();

    $self->throw("Plot data points parameter must be bool") if (!isbool($self->{plotpoints}));
    
}

sub _calcplotwidth {
    
    my $self = shift;
    
    my ($minwidth, $plotarea) = (0, 0);
    $minwidth = $self->{_xpadding} + $self->{_margin} * $self->{_width};
    $plotarea = $self->{_width} - $minwidth;
    $self->{_pointdist} = $plotarea / $#{$self->{values}};
    
    $self->warn("Image width is too small (Required: " . ceil($minwidth) . "px)") if ($minwidth >= $self->{_width});
    
}

sub _plotdata {
    
    my $self = shift;
    
    my ($lastx, $baseline, @values, @path);
    $lastx = $self->{_xpadding};
    @values = @{$self->{values}};
    
    @path = (["M", $lastx, $self->_vertalign($self->{_baseline})]);
    
    for (@values) {
    
        push(@path, ["L", $lastx, $self->_vertalign($_)]);
        $lastx += $self->{_pointdist};
    
    }
    
    push(@path, ["L", $lastx - $self->{_pointdist}, $self->_vertalign($self->{_baseline})]);
    
    $self->emptytag("path", { d              => join(" ", (map { join(" ", @{$_}) } @path), "Z"),
                              fill           => $self->{fill},
                              "fill-opacity" => $self->{opacity} }) if ($self->{fill} !~ m/^(:?none)?$/);
    
    shift(@path);
    pop(@path);
    $path[0]->[0] = "M";
    
    $self->emptytag("path", { d      => join(" ", map { join(" ", @{$_}) } @path),
                              stroke => $self->{stroke},
                              fill   => "none" }) if ($self->{stroke} !~ m/^(:?none)?$/);
    
    if ($self->{plotpoints}) {
        
        for (@path) {
        
            $self->emptytag("circle", { cx   => $_->[1],
                                        cy   => $_->[2],
                                        r    => min(1/200 * $self->{_width}, 1/25 * $self->{_pointdist}),
                                        fill => $self->{pointfill} || "black" });
        
        }
        
    }
    
}

sub _plotxaxis {
    
    my $self = shift;
    
    if (my @labels = @{$self->{labels}}) {
    
        my $lastx = $self->{_xpadding};
        @labels = @{$self->{labels}};
        
        for (0 .. $#labels) {
            
            $self->tagline("text", $labels[$_], { style                => "font-size: " . $self->{fontsize} . "px; font-family: Helvetica;",
                                                  "text-anchor"        => $self->{labelrotate} ? "end" : "middle",
                                                  "alignment-baseline" => "middle",
                                                  "dominant-baseline"  => "mathematical",
                                                  transform            => "translate(" . join(",", $lastx, $self->{_yarea}->[1] + $self->{_labelspace} + $self->{fontsize} / 2) . ") rotate(" . -abs($self->{labelrotate}) . ")" });
            
            $lastx += $self->{_pointdist};
            
        }
    
    }
    
    if ($self->{xname}) {
        
        $self->tagline("text", $self->{xname}, { "text-anchor" => "middle",
                                                 style         => "font-size: " . $self->{fontsize} . "px; font-family: Helvetica;",
                                                 x             => mean($self->{_xpadding}, $self->{_width}),
                                                 y             => $self->{_height} - 1/2 * $self->{fontsize} });
        
    }
    
}

sub _plotstdev {
    
    my $self = shift;
    
    my ($lastx, @y1, @y2);
    $lastx = $self->{_xpadding};
    @y1 = map { $self->_vertalign($_) } @{$self->{_values}->[0]};
    @y2 = map { $self->_vertalign($_) } @{$self->{_values}->[1]};
    
    for (0 .. $#y1) {
        
        $self->emptytag("line", { x1     => $lastx,
                                  x2     => $lastx,
                                  y1     => $y1[$_],
                                  y2     => $y2[$_],
                                  stroke => "black",
                                  style  => "stroke-width:" . min(1, 0.2 * min(1/200 * $self->{_width}, 1/25 * $self->{_pointdist})) . ";" });
        
        $lastx += $self->{_pointdist};
        
    }
    
}

1;
