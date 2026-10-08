package Interface::Rscape::Results;

use strict;
use Interface::Rscape::Results::Helix;
use RNA::Utils;

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ covFile              => undef,
                   helixCovFile         => undef,
                   cacofoldCovFile      => undef,
                   cacofoldHelixCovFile => undef,
                   _pairs               => {},
                   _cacofoldPairs       => {} }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    for (qw(covFile helixCovFile cacofoldCovFile cacofoldHelixCovFile)) {

        if (defined $self->{$_}) {

            $self->throw("Provided $_ does not exist") if (!-e $self->{$_});
            
            if ($_ =~ /^(?:cacofoldC|c)ovFile$/) { $self->_parseCovFile($_); }
            else { $self->_parseHelixCovFile($_); }

        }

    }

}

sub _parseCovFile {

    my $self = shift;
    my $file = shift;

    my ($leftPosIdx, $hasPercCanonical, %pairs);

    open(my $fh, "<", $self->{$file}) or $self->throw("Unable to read from $file \"" . $self->{$file} . "\"");
    while(my $line = <$fh>) {

        chomp($line);

        my $first = substr($line, 0, 1);

        if ($first eq "#") {

            if ($line =~ /left_pos/) {

                $line =~ s/^#\s+//;
                my @head = split " ", $line;
                ($leftPosIdx) = grep { $head[$_] eq "left_pos" } 0 .. $#head;
                $hasPercCanonical = 1 if ($head[-1] eq "canonical_pairs");

            }

        }
        else {

            if (defined $leftPosIdx) {

                my ($i, $j, @line);
                @line = split " ", $line;
                $i = $line[$leftPosIdx] - 1;
                $j = $line[$leftPosIdx + 1] - 1;
                $pairs{$i}->{$j} = { evalue        => $line[$leftPosIdx + 3],
                                     percCanonical => $hasPercCanonical ? $line[-1] : undef };
                
                if ($first eq "*") { $pairs{$i}->{$j}->{inStructure} = 1; }
                elsif ($first eq "~") { $pairs{$i}->{$j}->{compatible} = 1; }
                else { $pairs{$i}->{$j}->{incompatible} = 1; }

            }

        }

    }
    close($fh);

    # File is cacofold .cov file
    if (substr($file, 0, 8) eq "cacofold") { $self->{_cacofoldPairs} = \%pairs; }
    else { $self->{_pairs} = \%pairs; }

}

sub _parseHelixCovFile {

    my $self = shift;
    my $file = shift;

    my ($n, @helices);

    open(my $fh, "<", $self->{$file}) or $self->throw("Unable to read from $file \"" . $self->{$file} . "\"");
    local $/ = "\n\n";
    while(my $line = <$fh>) {

        if (!defined $n) {

            if ($line =~ /RMs = (\d+)/) { $n = $1; }
            else { $self->throw("$file \"" . $self->{$file} . "\ does not look like a valid .helixcov file"); }

        }
        else {

            next if ($line =~ /# aggregated NONE/);

            my ($helix, $evalue, @pvalues, @lines, @pairs);
            @lines = split /\n/, $line;

            if ($lines[1] =~ /# pvals: (.+)$/) { @pvalues = split /,/, $1; }
            if ($lines[2] =~ /# aggregated.+?E-value: (\S+)/) { $evalue = $1; }
            
            $lines[3] =~ s/^.+?\s+//;
            $lines[3] =~ tr/:_\-<>/...()/;
            @pairs = listpairs($lines[3]);

            next if (!@pairs);

            $helix = Interface::Rscape::Results::Helix->new( evalue  => $evalue,
                                                             pvalues => \@pvalues,
                                                             h5start => $pairs[0]->[0],
                                                             h5end   => $pairs[-1]->[0],
                                                             h3start => $pairs[0]->[1],
                                                             h3end   => $pairs[-1]->[1],
                                                             h5bases => [ map { $_->[0] } @pairs ],
                                                             h3bases => [ map { $_->[1] } @pairs ] );

            push(@helices, $helix);

        }

    }
    close($fh);

    if (substr($file, 0, 8) eq "cacofold") { $self->{_cacofoldHelices} = \@helices; } # File is cacofold .helixcov file
    else { $self->{_helices} = \@helices; }

}

sub compatiblePairs { 

    my $self = shift;
    my $cacofold = shift;

    return($self->_pairs("compatible", $cacofold)); 
    
}

sub incompatiblePairs { 

    my $self = shift;
    my $cacofold = shift;

    return($self->_pairs("incompatible", $cacofold)); 
    
}

sub inStructurePairs { 

    my $self = shift;
    my $cacofold = shift;

    return($self->_pairs("inStructure", $cacofold)); 
    
}

sub helices {

    my $self = shift;
    my $cacofold = shift;

    return($cacofold ? @{$self->{_cacofoldHelices}} : @{$self->{_helices}});

}

sub _pairs {

    my $self = shift;
    my $type = shift;
    my $cacofold = shift;

    my (@pairs, %pairs);
    %pairs = $cacofold ? %{$self->{_cacofoldPairs}} : %{$self->{_pairs}};
    @pairs = map {
        my $i = $_;
        map { [$i, $_] }
        grep { $pairs{$i}->{$_}->{$type} }
        keys %{ $pairs{$i} };
    } keys %pairs;

    return(@pairs);

}

1;