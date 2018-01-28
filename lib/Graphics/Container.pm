package Graphics::Container;

use strict;
use Core::Utils;
use Core::Mathematics qw(:all);
use POSIX;

use base qw(Data::XML);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ width       => 2480,
                   height      => 3508,
                   spacing     => 0,
                   _hasRNAarcs => 0,
                   _hasBarplot => 0,
                   _spacing    => [],
                   _objects    => [] }, \%parameters);
    
    $self->_validate();
    
    return($self);
    
}

sub _validate {
    
    my $self = shift;
    
    $self->SUPER::_validate();
    
    $self->throw("Width must be a positive integer > 0") if (!ispositive($self->{width}) ||
                                                             !$self->{width});
    $self->throw("Height must be a positive integer > 0") if (!ispositive($self->{height}) ||
                                                              !$self->{height});
    
    $self->throw("Vertical spacing must be comprised between 0 and 1") if (!ispositive($self->{spacing}) ||
                                                                           !inrange($self->{spacing}, [0, 1]));
    
}

sub addobject {
    
    my $self = shift;
    my $object = shift if (@_);
    my $spacing = shift // $self->{spacing};
 
    $self->throw("Vertical spacing must be >= 0") if (!ispositive($spacing));
 
    if (!blessed($object) ||
        !$object->isa("Graphics::Object")) {
        
        $self->warn("Method requires a valid Graphics::Object object");
                
        next;
        
    }
    
    $object->_width($self->{width});
    push(@{$self->{_objects}}, $object);
    push(@{$self->{_spacing}}, $spacing * $self->{width});
    
}

sub addobjects {
    
    my $self = shift;
    my @objects = @_ if (@_);
    
    for(my $i=0; $i < @objects; $i++) {
        
        my ($object, $next);
        $object = $objects[$i];
        $next = $objects[$i+1] if ($i + 1 < @objects);
        
        if (!blessed($next)) {
            
            $self->addobject($object, $next);
            $i++;
            
        }
        else { $self->addobject($object); }
        
        $self->{_hasRNAarcs} = 1 if (ref($object) eq "Graphics::Object::RNAarcs");
        $self->{_hasBarplot} = 1 if (ref($object) eq "Graphics::Object::Barplot");
        $self->{_hasRuler} = 1 if (ref($object) eq "Graphics::Object::Ruler");
        
    }
    
}

sub xml {
    
    my $self = shift;
    
    $self->clearxml();
    
    my ($trueheight, $totobjheight, $maxxpadding, $lasty);
    $trueheight = $self->{height};
    $trueheight -= sum(@{$self->{_spacing}}[0 .. $#{$self->{_spacing}} - 1]) if (@{$self->{_objects}} > 1);
    $totobjheight = sum(map { $_->height() } @{$self->{_objects}});
    $lasty = 0;
    
    $self->opentag("svg", { width               => $self->{width},
                            height              => $self->{height},
                            viewBox             => join(" ", 0, 0, $self->{width}, $self->{height}),
                            preserveAspectRatio => "xMinYMin",
                            xmlns               => "http://www.w3.org/2000/svg",
                            version             => "1.1" });
    
    for (0 .. $#{$self->{_objects}}) {
        
        my ($height, $object);
        $object = $self->{_objects}->[$_];
        $height = round($object->height() / $totobjheight * $trueheight);
        $object->_height($height);
        $object->_starty($lasty);
        $object->_preplotcalc() if ($object->can("_preplotcalc"));
        
        $lasty += $height + $self->{_spacing}->[$_];
        
    }
    
    $maxxpadding = max(map { $_->_xpadding() } @{$self->{_objects}});
    
    # This is to handle the special case in which we have an RNAarcs plot and
    # a bar plot that should be aligned. Since multiple RNAarcs and bar plots
    # can be present, and they can be independent from each others, we create
    # a compatibility table, and re-align each RNAarcs plot by 1/2 of bars width
    
    if ($self->{_hasBarplot} &&
        ($self->{_hasRNAarcs} ||
         $self->{_hasRuler})) {
        
        my (@barwidths, %plotgroups, %rnaarcs, %rulers);
        
        for (0 .. $#{$self->{_objects}}) {
            
            my ($object, $ref);
            $object = $self->{_objects}->[$_];
            $ref = ref($object);
            
            if ($ref eq "Graphics::Object::Barplot") {
            
                $object->_xpadding($maxxpadding);
                $object->_calcplotwidth();
                $plotgroups{$object->_nvalues()} = $object->_barwidth() / 2;
                push(@barwidths, $object->_barwidth() / 2);
            
            }
            elsif ($ref eq "Graphics::Object::RNAarcs") { $rnaarcs{$_} = 1; }
            elsif ($ref eq "Graphics::Object::Ruler") { $rulers{$_} = 1; }
        
        }
        
        if (my $diff = diff(scalar(keys(%rulers)), scalar(@barwidths))) {
            
            if (isnegative($diff)) { splice(@barwidths, 0, abs($diff)); }
            else { @barwidths = (@barwidths, ($barwidths[-1]) x $diff); }
            
        }
        
        for (0 .. $#{$self->{_objects}}) {
            
            my ($object, $extrawidth);
            $object = $self->{_objects}->[$_];
            $extrawidth = 0;
            
            if (exists $rnaarcs{$_} ||
                exists $rulers{$_}) {
            
                $extrawidth = exists $rnaarcs{$_} ? $plotgroups{$object->_length()} : shift(@barwidths);
                $object->_width($self->{width} - $extrawidth);
            
            }
            
            $object->_xpadding($extrawidth + $maxxpadding);
            $self->addxmlblock($object->xml());
            
        }
        
    }
    else {
        
        foreach my $object (@{$self->{_objects}}) {
        
            $object->_xpadding($maxxpadding);
            $self->addxmlblock($object->xml());
            
        }
        
    }
    
    $self->closelasttag();
    $self->SUPER::xml();
    
}


1;