package Data::Sequence;

use strict;
use Core::Mathematics;
use Core::Utils;
use Data::Sequence::Utils;

use base qw(Core::Base);

sub new {
    
    my $class = shift;
    my %parameters = @_;
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ id            => undef,
                   fullId        => undef,
                   description   => undef,
                   sequence      => undef,
                   start         => undef,
                   end           => undef,
                   orientation   => 5,
                   type          => "AUTO",
                   maskIUPAC     => 0,
                   circular      => 0,
                   references    => [],
                   _length       => undef }, \%parameters);
    
    if ($class =~ m/^Data::Sequence::\w+$/) { return($self); }
    else {
    
        $self->_validate();
        $self->_fixproperties();
        
    }
    
    return($self);
    
}

sub _validate {
    
    my $self = shift;

    $self->throw("Sequence contains invalid characters") if (defined $self->{sequence} && !isseq($self->{sequence}, "-"));
    $self->throw("Invalid sequence type \"" . $self->{type} . "\"") unless ($self->{type} =~ m/^(?:(?:D|R)NA|AA|AUTO)$/i);
    
    # A fullId passed to the constructor is split into id and description; an id
    # passed without a fullId has the fullId derived from it
    if (defined $self->{fullId} && !defined $self->{id}) { $self->fullId($self->{fullId}); }
    else { $self->fullId(); }

    
}

sub _fixproperties {
    
    my $self = shift;
    
    $self->{type} = uc($self->{type}) if (defined $self->{type});
    $self->{orientation} = uc($self->{orientation});
    
    if (defined $self->{sequence}) {
        
        # "AUTO" asks for the type to be guessed from the sequence itself. The
        # IUPAC tests have to come before the fallback to AA: isdna()/isrna()
        # only accept ACGT(U)N, so a reference carrying degenerate bases would
        # otherwise be called a protein, and maskIUPAC would then be skipped on
        # exactly the sequences it exists for
        if (!defined $self->{type} || $self->{type} eq "AUTO") {
            
            if (isdna($self->{sequence}, "-")) { $self->{type} = "DNA"; }
            elsif (isrna($self->{sequence}, "-")) { $self->{type} = "RNA"; }
            elsif (isiupac($self->{sequence}, "-")) { $self->{type} = $self->{sequence} =~ m/U/i ? "RNA" : "DNA"; }
            else { $self->{type} = "AA"; }
            
        }
    
        
        if ($self->{type} eq "AA") {
            
            $self->{sequence} = uc($self->{sequence});
            $self->{orientation} =~ tr/53/NC/ if (defined $self->{orientation});
            $self->{orientation} = "N" unless ($self->{orientation} =~ m/^[NC]$/);
            
        }
        else {
            
            $self->{orientation} =~ tr/NC/53/ if (defined $self->{orientation});
            $self->{orientation} = "5" unless ($self->{orientation} =~ m/^[53]$/);
            
        }
        
        $self->{_length} = length($self->{sequence});
        
        # The degenerate codes are listed explicitly, exactly as in 2.9.7, rather
        # than masked through a negated character class: a whitelist cannot mask a
        # base it was not meant to touch, it preserves case by construction, and
        # it leaves alignment gaps alone. Two sequential substitutions must not be
        # used here, as each would see the other's output
        $self->{sequence} =~ tr/BDHKMNRSVWYbdhkmnrsvwy/NNNNNNNNNNNnnnnnnnnnnn/ if ($self->{type} ne "AA" && $self->{maskIUPAC});
        
    }
    
}

sub id {
    
    my $self = shift;
    my $id = shift;
    
    if (defined $id) {
        
        $self->{id} = $id;
        $self->{fullId} = $self->{id} . " " . $self->{description} if (defined $self->{description});
        
    }
    
    return($self->{id});
    
}

sub fullId {
    
    my $self = shift;
    my $fullId = @_ ? shift : undef;
    
    if (defined $fullId) {
        
        my @id = split(" ", $fullId);
        $self->{id} = shift(@id);
        $self->{description} = join(" ", @id);
        $self->{fullId} = $fullId;
            
    }
    elsif (!defined $self->{fullId}) {
        
        if (defined $self->{id}) {
            
            $self->{fullId} = $self->{id};
            $self->{fullId} .= " " . $self->{description} if (defined $self->{description});
            
        }
        
    }
    
    return($self->{fullId});
    
}


sub description {
    
    my $self = shift;
    my $description = shift;
    
    if (defined $description) {
        
        $self->{description} = $description;
        $self->{fullId} = $self->{id} . " " . $self->{description} if (defined $self->{id});
        
    }
    
    return($self->{description});
    
}

sub sequence {
    
    my $self = shift;
    my $sequence = shift;
    
    if (defined $sequence &&
        isseq($sequence, "-")) {
    
        $self->{sequence} = $sequence;
        $self->_fixproperties();
        
    }
    
    return($self->{sequence});
    
}

sub start {
    
    my $self = shift;
    my $start = shift;
    
    $self->{start} = $start if (isreal($start));
    
    return($self->{start});
    
}

sub end {
    
    my $self = shift;
    my $end = shift;
    
    $self->{end} = $end if (isreal($end));
    
    return($self->{end});
    
}

sub orientation {
    
    my $self = shift;
    my $orientation = shift;
    
    if ($orientation =~ m/^[53NC]$/) {
        
        $self->_fixproperties();
        $self->{orientation} = uc($orientation);
        
    }
    
    return($self->{orientation});
    
}

sub type {
    
    my $self = shift;
    my $type = shift;
    
    if ($type =~ m/^([DR]NA|AA)$/i) {
    
        $self->{type} = uc($type);    
        $self->_fixproperties();
        
    }
    
    return($self->{type});
    
}

sub circular {
    
    my $self = shift;
    my $circular = shift;
    
    $self->{circular} = $circular if ($circular =~ m/^[01]$/);
    
    return($self->{circular});
    
}

sub length {
    
    my $self = shift;
    
    $self->{_length} = length($self->{sequence}) unless(defined $self->{_length});
    
    return($self->{_length});
    
}

sub extract {
    
    my $self = shift;
    my $start = shift || 1;
    my $end = shift || $self->length();
    
    my ($sequence);
    
    $self->throw("Start/end values must be positive integers") unless (ispositive($start) && ispositive($end) &&
                                                                       isint($start) && isint($end));
    
    if ($start <= $self->length() &&
        $end <= $self->length() &&
        $start <= $end) {
        
        $sequence = substr($self->sequence(), $start - 1, $end - $start + 1);
        
    }
    else { $self->warn("Out of range (Length: " . $self->length() . ")"); }
    
    return($sequence);
    
}

sub hardmask {
    
    my $self = shift;
    
    if ($self->{type} =~ m/^(D|R)NA$/) { $self->{sequence} =~ s/[acgtun]/N/g; }
    else { $self->warn("Unable to hardmask an amino acid sequence"); }
    
}

sub unmask {
    
    my $self = shift;
    
    $self->{sequence} = uc($self->{sequence});
    
}

sub DESTROY {
    
    my $self = shift;
    
    delete($self->{sequence});
    
}

1;
