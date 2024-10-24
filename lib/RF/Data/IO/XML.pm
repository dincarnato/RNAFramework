package RF::Data::IO::XML;

use strict;
use Core::Utils;
use Data::Sequence::Utils;

use base qw(Data::IO::XML);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ (map { "_" . $_ => undef } qw(id sequence length tool algorithm
                                                 keep maxdist scoring norm reactive
                                                 win offset remap max pseudo maxumut
                                                 maxmutrate tosmaller combined structure)),
                   (map { "_" . $_            => [],
                          "_" . $_ . "-error" => [] } qw(reactivity probability shannon score
                                                         ratio)) }, \%parameters);

    $self->_validate();
    $self->_openfh();
    $self->_readxml();

    return($self);

}

sub _readxml {

    my $self = shift;

    my ($tree, %attribs);
    $tree = $self->read();
    
    $self->throw("File does not look like a valid RNA Framework XML file") if (!$tree->hasNode("/data/transcript") || !$tree->hasNode("/data/transcript/sequence"));

    $tree = $tree->getNode("/data");
    %attribs = $tree->attribute();

    foreach my $attrib (keys %attribs) {

        $self->warn("Unrecognized attribute \"$attrib\"") if (!exists $self->{"_" . $attrib});

        $self->{"_" . $attrib} = $attribs{$attrib};

    }

    $tree = $tree->getNode("/transcript");
    %attribs = $tree->attribute();

    foreach my $attrib (keys %attribs) {

        $self->warn("Unrecognized attribute \"$attrib\"") if (!exists $self->{"_" . $attrib});

        $self->{"_" . $attrib} = $attribs{$attrib};

    }

    foreach my $node ($tree->listNodes()) {

        $self->{"_$node"} = $tree->getNode("/$node")->value();
        $self->{"_$node"} =~ s/\s//g;

        if ($node ne "sequence") { $self->{"_$node"} = [ split(",", $self->{"_" . $node}) ]; }
        else { $self->throw("Sequence contains invalid characters") if (!isna($self->{"_$node"})); }

    }

    $self->throw("Sequence and reactivity have unequal lengths") if (@{$self->{_reactivity}} && length($self->{_sequence}) != @{$self->{_reactivity}});
    $self->throw("Sequence and reactivity-error have unequal lengths") if (@{$self->{"_reactivity-error"}} && length($self->{_sequence}) != @{$self->{"_reactivity-error"}});
    $self->throw("Sequence and probability have unequal lengths") if (@{$self->{_probability}} && length($self->{_sequence}) != @{$self->{_probability}});
    $self->throw("Sequence and Shannon entropy have unequal lengths") if (@{$self->{_shannon}} && length($self->{_sequence}) != @{$self->{_shannon}});
    $self->throw("Sequence and score have unequal lengths") if (@{$self->{_score}} && length($self->{_sequence}) != @{$self->{_score}});
    $self->throw("Sequence and ratio have unequal lengths") if (@{$self->{_ratio}} && length($self->{_sequence}) != @{$self->{_ratio}});

}

sub id { return($_[0]->{_id}); }

sub sequence { return($_[0]->{_sequence}); }

sub length { return($_[0]->{_length}); }

sub tool { return($_[0]->{_tool}); }

sub algorithm { return($_[0]->{_algorithm}); }

sub keep { return(defined $_[0]->{_keep} ? $_[0]->{_keep} : $_[0]->{_reactive}); }

sub maxdist { return($_[0]->{_maxdist}); }

sub scoring { return($_[0]->{_scoring}); }

sub norm { return($_[0]->{_norm}); }

sub reactive { return(defined $_[0]->{_reactive} ? $_[0]->{_reactive} : $_[0]->{_keep}); }

sub window { return($_[0]->{_win}); }

sub offset { return($_[0]->{_offset}); }

sub remap { return($_[0]->{_remap}); }

sub max { return($_[0]->{_max}); }

sub pseudocount { return($_[0]->{_pseudo}); }

sub maxuntreatedmut { return($_[0]->{_maxumut}); }

sub maxmutationrate { return($_[0]->{_maxmutrate}); }

sub tosmaller { return($_[0]->{_tosmaller}); }

sub combined { return($_[0]->{_combined}); }

sub reactivity { return(wantarray() ? @{$_[0]->{_reactivity}} : $_[0]->{_reactivity}); }

sub reactivity_error { return(wantarray() ? @{$_[0]->{"_reactivity-error"}} : $_[0]->{"_reactivity-error"}); }

sub probability { return(wantarray() ? @{$_[0]->{_probability}} : $_[0]->{_probability}); }

sub shannon { return(wantarray() ? @{$_[0]->{_shannon}} : $_[0]->{_shannon}); }

sub score { return(wantarray() ? @{$_[0]->{_score}} : $_[0]->{_score}); }

sub ratio { return(wantarray() ? @{$_[0]->{_ratio}} : $_[0]->{_ratio}); }

1;
