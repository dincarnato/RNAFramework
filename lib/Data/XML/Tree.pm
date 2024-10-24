package Data::XML::Tree;

use strict;
use Core::Mathematics;
use Core::Utils;

use base qw(Core::Base);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ tree => {} }, \%parameters);

    return($self);

}

sub attribute {

    my $self = shift;
    my $attrib = shift;

    if (defined $attrib) {

        return($self->{tree}->{xml_attribs}->{$attrib}) if (exists $self->{tree}->{xml_attribs}->{$attrib});

        $self->warn("No attribute \"$attrib\"");

    }
    else { return(wantarray() ? %{$self->{tree}->{xml_attribs}} : $self->{tree}->{xml_attribs}) if (exists $self->{tree}->{xml_attribs}); }

}

sub value {

    my $self = shift;

    return(unquotemeta($self->{tree}->{xml_value}));

}

sub listNodes {

    my $self = shift;

    if (!keys %{$self->{tree}}) { $self->warn("Empty XML tree"); }
    else {

        my @nodes = map { $_ } grep { $_ !~ m/^xml/ } sort keys %{$self->{tree}};

        return(wantarray() ? @nodes : \@nodes);

    }

}

sub hasNode {

    my $self = shift;
    my $nodes = shift;

    return if (!defined $nodes || !keys %{$self->{tree}});

    $nodes =~ s/^\/|\/$//;

    my $tree = $self;

    foreach my $node (split("/", $nodes)) {

        return if (!exists $tree->{tree}->{$node} || substr($node, 0, 4) eq "xml_");

        $tree = $tree->getNode($node);

    }

    return(1);

}

sub getNode {

    my $self = shift;
    my $nodes = shift;

    if (!keys %{$self->{tree}}) { $self->warn("Empty XML tree"); }
    else {

        $nodes = (sort keys %{$self->{tree}})[0] if (!defined $nodes);
        $nodes =~ s/^\/|\/$//;

        my ($subTree, @nodes, @trees);
        $subTree = $self->{tree};
        @nodes = split("/", $nodes);

        foreach my $i (0 .. $#nodes) {

            my $node = $nodes[$i];

            $self->throw("Attempt to access a private key in XML tree (key: " . $node . ")") if (substr($node, 0, 4) eq "xml_");

            if (ref($subTree) eq "HASH") {

                if (exists $subTree->{$node}) { $subTree = $subTree->{$node}; }
                else {

                    $self->warn("Node \"" . $node . "\" not found");

                    return();

                }

            }
            else { $self->throw("Cannot descend further into XML tree" . ($i > 0 ? " (node \"" . $nodes[$i - 1] . "\" is an ARRAY reference)" : undef)); }

        }

        if (ref($subTree) eq "ARRAY") { 
            
            my @subTree = map { __PACKAGE__->new(tree => $_) } @$subTree;

            return(wantarray() ? @subTree : \@subTree); 
            
        }
        else { return(__PACKAGE__->new(tree => $subTree)); }

    }

    return();

}

1;
