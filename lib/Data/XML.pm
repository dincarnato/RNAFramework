package Data::XML;

use strict;
use Core::Mathematics;

use base qw(Core::Base);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ heading       => 1,
                   autoclose     => 1,
                   indent        => 0,
                   _indent       => 0,
                   _xml          => undef,
                   _tags         => [],
                   _text         => 0 }, \%parameters);
    
    $self->_validate() if ($class =~ m/^Data::XML$/);

    return($self);
    
}

sub _validate {
    
    my $self = shift;
    
    $self->throw("Heading parameter must be BOOL") if ($self->{heading} !~ m/^[01]$/);
    $self->throw("Autoclose parameter must be BOOL") if ($self->{autoclose} !~ m/^[01]$/);
    $self->throw("Indent parameter must be a positive integer") if (!ispositive($self->{indent}) ||
                                                                    !isint($self->{indent}));
    
    $self->{_xml} = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" if ($self->{heading});
    $self->{_indent} = $self->{indent};

}

sub heading {
    
    my $self = shift;
    my $heading = shift if (@_);
    
    if (defined $heading) {
        
        $self->throw("Heading parameter must be BOOL") if ($heading !~ m/^[01]$/);
    
        $self->{heading} = $heading;
        
    }
    
    return($self->{heading});
    
}

sub autoclose {
    
    my $self = shift;
    my $autoclose = shift if (@_);
    
    if (defined $autoclose) {
        
        $self->throw("Autoclose parameter must be BOOL") if ($autoclose !~ m/^[01]$/);
    
        $self->{autoclose} = $autoclose;
        
    }
    
    return($self->{autoclose});
    
}

sub clearxml {
    
    my $self = shift;
    
    undef($self->{_xml});
    
    $self->{_xml} = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" if ($self->{heading});
    
}

sub opentag {
    
    my $self = shift;
    my ($tag, $attributes) = @_ if (@_);
    
    $attributes = {} if (!defined $attributes);
    
    if (defined $tag) {
        
        $self->_validatetag($tag);
        
        $self->throw("Attributes should be provided as an HASH reference") if (ref($attributes) ne "HASH");
    
        $self->{_xml} .= ("\t" x $self->{_indent}) . "<" . $tag;
        $self->{_xml} .= " " . $self->_validatechars($_) . "=\"" . $self->_validatechars($attributes->{$_}) . "\"" for (sort keys %{$attributes});
        $self->{_xml} .= ">\n";
        
        $self->{_indent}++;
        
        push(@{$self->{_tags}}, $tag);
    
    }
    
}

sub addtext {
    
    my $self = shift;
    my $text = shift if (@_);
    
    if (defined $text) {
        
        $self->throw("Cannot add text outside of a tag") unless(@{$self->{_tags}});
        
        $text =~ s/\n/"\n" . "\t" x $self->{_indent}/eg;
        $self->{_xml} .= ("\t" x $self->{_indent}) . $self->_validatechars($text) . "\n";
        
    }
    
}

sub closebogustag {
    
    my $self = shift; 
    my $tag = shift if (@_);
    
    if (defined $tag) {
        
        $self->_validatetag($tag);
        
        $self->{_indent}-- if ($self->{_indent});
        $self->{_xml} .= ("\t" x $self->{_indent}) . "</" . $tag . ">\n";
        
    }
    
    
}

sub closetag {
    
    my $self = shift; 
    my $tag = shift if (@_); 
    
    if (defined $tag) {
        
        if (@{$self->{_tags}}) { $self->throw("Tag \"" . $tag . "\" cannot be closed before tag \"" . $self->{_tags}->[-1] . "\"") if ($tag ne $self->{_tags}->[0]); }
        else { $self->throw("Tag \"" . $tag . "\" is not open"); }
        
        $self->{_indent}--;
        $self->{_xml} .= ("\t" x $self->{_indent}) . "</" . $tag . ">\n";
        
        pop(@{$self->{_tags}});
        
    }
    
}

sub closelasttag {
    
    my $self = shift;
    
    if (my $tag = pop(@{$self->{_tags}})) {
        
        $self->{_indent}--;
        $self->{_xml} .= ("\t" x $self->{_indent}) . "</" . $tag . ">\n";
        
    }
    
}

sub closealltags {
    
    my $self = shift;
    
    while (my $tag = pop(@{$self->{_tags}})) {
        
        $self->{_indent}--;
        $self->{_xml} .= ("\t" x $self->{_indent}) . "</" . $tag . ">\n";
        
    }
    
}

sub tagline {
    
    my $self = shift;
    my ($tag, $text, $attributes) = @_ if (@_);
    
    $attributes = {} if (!defined $attributes);
    
    #$self->warn("Tag line added outside of a root element") unless(@{$self->{_tags}});
    
    if (defined $tag) {
    
        $self->_validatetag($tag);
        
        $self->throw("Attributes should be provided as an HASH reference") if (ref($attributes) ne "HASH");
    
        $self->{_xml} .= ("\t" x $self->{_indent}) . "<" . $tag;
        $self->{_xml} .= " " . $self->_validatechars($_) . "=\"" . $self->_validatechars($attributes->{$_}) . "\"" for (sort keys %{$attributes});
        $self->{_xml} .= ">" . $self->_validatechars($text) . "</" . $tag . ">\n";

    }
                                                                                                                           
}

sub emptytag {
    
    my $self = shift;
    my ($tag, $attributes) = @_ if (@_);
    
    $attributes = {} if (!defined $attributes);
    
    if (defined $tag) {
    
        $self->_validatetag($tag);
        
        $self->throw("Attributes should be provided as an HASH reference") if (ref($attributes) ne "HASH");
        
        
        $self->{_xml} .= ("\t" x $self->{_indent}) . "<" . $tag;
        $self->{_xml} .= " " . $self->_validatechars($_) . "=\"" . $self->_validatechars($attributes->{$_}) . "\"" for (sort keys %{$attributes});
        $self->{_xml} .= " \/>\n";
        
    }
    
}

sub comment {
    
    my $self = shift;
    my $comment = shift if (@_);
    
    if (defined $comment) {
        
        $self->throw("Comments cannot contain double hypens") if ($comment =~ m/\-\-/);
        
        $self->{_xml} .= ("\t" x $self->{_indent}) . "<!-- " . $comment . " -->\n";
        
    }
    
}

sub addxmlblock {
    
    my $self = shift;
    my $xml = shift if (@_);
    my $validate = shift if (@_);
    
    if (defined $xml) {
        
        my $islibXMLinstalled = eval { require XML::LibXML; 1; };

        if ($islibXMLinstalled && $validate) {
            
            eval { my $dom = XML::LibXML->load_xml(string => $xml); };
            
            $self->throw("Malformed XML code block") if ($@);
            
        }
        
        $xml =~ s/^/"\t" x $self->{_indent}/egm;
        $xml =~ s/\n*$/\n/;
        
        $self->{_xml} .= $xml;
        
    }
    
}

sub xml {
    
    my $self = shift;
    
    $self->closealltags() if ($self->{autoclose});
    
    $self->warn("XML code with " . scalar(@{$self->{_tags}}) . " still open tags") if (@{$self->{_tags}});
    
    return($self->{_xml});
    
}

sub _validatetag {
    
    my $self = shift;
    my $tag = shift if (@_);
    
    if (defined $tag) {
        
        $tag =~ s/ /_/g;  # Remove spaces
        
        $self->throw("Tag name cannot begin with the reserved word \"XML\"") if ($tag =~ m/^XML/i);
        print "\ntag: $tag\n" and $self->throw("Tag name can contain only letters, digits, hyphens and underscores") if ($tag !~ m/^[\w-]+$/);
        $self->throw("Tag name must begin with a letter or an underscore") if ($tag =~ m/^\d/);
        
    }
    
}

sub _validatechars {
    
    my $self = shift;
    my $text = shift if (@_);
    
    if (defined $text) {
        
        $text =~ s/\&/\&amp;/g;
        $text =~ s/\</\&lt;/g;
        $text =~ s/\"/\&quot;/g;
        $text =~ s/\>/\&gt;/g;
        $text =~ s/'/\&apos;/g;
        
    }
    
    return($text);
    
}

1;