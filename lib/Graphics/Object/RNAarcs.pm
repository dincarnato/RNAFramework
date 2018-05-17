package Graphics::Object::RNAarcs;

use strict;
use Core::Utils;
use Core::Mathematics qw(:all);
use POSIX;

use base qw(Graphics::Object);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    $parameters{stroke} = [$parameters{stroke}] if (ref($parameters{stroke}) ne "ARRAY");
    $parameters{pkstroke} = [$parameters{pkstroke}] if (ref($parameters{pkstroke}) ne "ARRAY");
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ length    => undef,
                   flip      => "up",
                   basepairs => [],
                   pkpairs   => [],
                   stroke    => ["black"],
                   pkstroke  => ["black"],
                   pkdashed  => 1 }, \%parameters);
    
    $self->_validate();
    
    return($self);
    
}

sub _validate {
    
    my $self = shift;
    
    my $maxlen = 0;
    
    $self->SUPER::_validate();
    
    $self->throw("Base-pairs must be provided as an ARRAY reference") if (ref($self->{basepairs}) ne "ARRAY");
    $self->throw("Pseudoknotted base-pairs must be provided as an ARRAY reference") if (ref($self->{pkpairs}) ne "ARRAY");
    $self->throw("Base-pairs array is empty") if (!@{$self->{basepairs}});
    $self->throw("Invalid flip mode") if ($self->{flip} !~ m/^up|down$/i);
    $self->throw("Pseudoknots dashed line parameter must be bool") if (!isbool($self->{pkdashed}));
    
    for (@{$self->{basepairs}}, @{$self->{pkpairs}}) {
        
        $self->throw("Base-pairs must be provided as ARRAY references") if (ref($_) ne "ARRAY");
        $self->throw("Base indexes must be integer >= 0") if (!ispositive(@{$_}) ||
                                                              !isint(@{$_}));
        
        $maxlen = max($maxlen, @{$_});
        
    }
    
    $maxlen++;
    
    $self->{length} = $maxlen if (!$self->{length} ||
                                  $self->{length} < $maxlen);
    $self->throw("RNA length must be an integer > 1") if (!isint($self->{length})||
                                                          !ispositive($self->{length}) ||
                                                          $self->{length} <= 1);
    
    
}

sub _length { return($_[0]->{length}); }

sub xml {
    
    my $self = shift;
    
    my ($maxrad, $transform, $maxstroke, @allpairs,
        @coords, @stroke);
    $maxrad = 0;
    $maxstroke = min(4, diff($self->_orizontalign(1), $self->_orizontalign(0)) / 2 * 0.9);
    @stroke = @{$self->{stroke}};
    @stroke = (@stroke, ($stroke[-1]) x (@{$self->{basepairs}} - @stroke));
    
    if (@{$self->{pkpairs}}) {
        
        @stroke = @{$self->{pkstroke}};
        @stroke = (@stroke, ($stroke[-1]) x (@{$self->{basepairs}} + @{$self->{pkpairs}} - @stroke));
    
    }
    
    @allpairs = map { [@{$_}, 0] } @{$self->{basepairs}};
    @allpairs = (@allpairs, (map { [@{$_}, 1] } @{$self->{pkpairs}}));
  
    for (@allpairs) {
        
        my ($x1, $x2, $y1, $y2, $diameter);
        $x1 = $self->_orizontalign($_->[0]);
        $y1 = 0;
        $x2 = $self->_orizontalign($_->[1]);
        $diameter = $x2 - $x1;
        $y2 = ($y1 + 2 * $diameter) / 3;
        $maxrad = max($maxrad, $diameter / 2);
        
        push(@coords, [$x1, $x2, $y1, $y2, $_->[2]]);
        
    }
    
    $maxrad += $maxstroke;  # Modified from: "translate(0 " . (min($self->{_height}, $maxrad) + $self->{_starty}) . ") scale(1 -" . (min($self->{_height}, $maxrad) / $maxrad) . ")" :
    $transform = $self->{flip} =~ m/^up$/i ? "translate(0 " . ($self->{_height} + $self->{_starty}) . ") scale(1 -" . (min($self->{_height}, $maxrad) / $maxrad) . ")" :
                                             "translate(0 " . $self->{_starty} . ") scale(1 " . (min($self->{_height}, $maxrad) / $maxrad) . ")";
    $self->opentag("g", { transform => $transform });
    
    for (0 .. $#coords) {
        
        my ($x1, $x2, $y1, $y2,
            $pk, $attributes);
        ($x1, $x2, $y1, $y2, $pk) = @{$coords[$_]};
        $attributes = { d      => "M" . join(" ", $x1, $y1, "C", $x1, $y2 . ",", $x2, $y2 . ",", $x2, $y1),
                        stroke => $stroke[$_] || "black",
                        style  => "stroke-width: " . $maxstroke,
                        fill   => "none" };
        $attributes->{"stroke-dasharray"} = "2, 2" if ($pk &&
                                                       $self->{pkdashed});
        
        
        $self->emptytag("path", $attributes);
        
    }
    
    $self->closelasttag();
    $self->SUPER::xml();
    
}

sub _orizontalign {
    
    my $self = shift;
    my $x = shift if (@_);
    
    return(maprange(0, $self->{length} - 1, $self->{_xpadding}, $self->{_width} - $self->{_margin} * $self->{_width}, $x));
    
}

1;