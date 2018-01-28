package RF::Data::IO::XML;

use strict;
use Core::Utils;
use Data::Sequence::Utils;
use Fcntl qw(SEEK_SET SEEK_END);
use RF::Data::RC;
use XML::LibXML;

use base qw(Data::IO);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ _id          => undef,
                   _sequence    => undef,
                   _length      => undef,
                   _tool        => undef,
                   _algorithm   => undef,
                   _keep        => undef,
                   _maxdist     => undef,
                   _scoring     => undef,
                   _norm        => undef,
                   _reactive    => undef,
                   _win         => undef,
                   _offset      => undef,
                   _remap       => undef,
                   _max         => undef,
                   _pseudo      => undef,
                   _maxumut     => undef,
                   _tosmaller   => undef,
                   _combined    => undef,
                   _reactivity  => [],
                   _rerror      => [],
                   _probability => [],
                   _shannon     => [],
                   _score       => [],
                   _ratio       => [] }, \%parameters);
    
    $self->_readxml();
    $self->_validate();
    
    return($self);
    
}

sub _readxml {
    
    my $self = shift;
    
    my ($xmlref, $reactivity, $probability, $shannon,
        $score, $ratio, $rerror,);
    
    eval { $xmlref = XML::LibXML->load_xml(location => $self->{file}); };
        
    if ($@) {
        
        $@ =~ s/[\n\^]//g;
        $self->throw("XML::LibXML error (\"" . $@ . "\")");
        
    }

    for (qw(tool algorithm keep maxdist
            scoring norm reactive win
            offset remap max pseudo
            maxumut tosmaller combined)) {
        
        my $key = "_" . $_;
        $self->{"_" . $_} = $xmlref->findnodes("/data/\@" . $_)->to_literal();
        $self->{$key} = "$self->{$key}";
        
    }

    $self->{"_" . $_} = $self->{"_" . $_} =~ m/^TRUE|yes|1$/i ? 1 : 0 for (qw(remap tosmaller combined));
    
    $self->{_keep} = join("", iupac2nt($self->{_keep}));
    $self->{_reactive} = join("", iupac2nt($self->{_reactive}));
    
    $self->{_id} = $xmlref->findnodes("/data/transcript/\@id")->to_literal();
    $self->{_length} = $xmlref->findnodes("/data/transcript/\@length")->to_literal();
    $self->{_sequence} = $xmlref->findnodes("/data/transcript/sequence")->to_literal();
    
    $reactivity = $xmlref->findnodes("/data/transcript/reactivity")->to_literal();
    $rerror = $xmlref->findnodes("/data/transcript/reactivity-error")->to_literal();
    $probability = $xmlref->findnodes("/data/transcript/probability")->to_literal();
    $shannon = $xmlref->findnodes("/data/transcript/shannon")->to_literal();
    $ratio = $xmlref->findnodes("/data/transcript/ratio")->to_literal();
    $score = $xmlref->findnodes("/data/transcript/score")->to_literal();
    
    $self->{_sequence} =~ s/\s+?//g;
    $self->{_sequence} = dna2rna($self->{_sequence});
    $reactivity =~ s/\s+?//g;
    $rerror =~ s/\s+?//g;
    $probability =~ s/\s+?//g;
    $score =~ s/\s+?//g;
    $ratio =~ s/\s+?//g;
    $shannon =~ s/\s+?//g;
    
    $self->{_reactivity} = [ split(/,/, $reactivity) ];
    $self->{_rerror} = [ split(/,/, $rerror) ];
    $self->{_probability} = [ split(/,/, $probability) ];
    $self->{_score} = [ split(/,/, $score) ];
    $self->{_ratio} = [ split(/,/, $ratio) ];
    $self->{_shannon} = [ split(/,/, $shannon) ];
    
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

sub tosmaller { return($_[0]->{_tosmaller}); }

sub combined { return($_[0]->{_combined}); }

sub reactivity { return(wantarray() ? @{$_[0]->{_reactivity}} : $_[0]->{_reactivity}); }

sub reactivity_error { return(wantarray() ? @{$_[0]->{_rerror}} : $_[0]->{_rerror}); }

sub probability { return(wantarray() ? @{$_[0]->{_probability}} : $_[0]->{_probability}); }

sub shannon { return(wantarray() ? @{$_[0]->{_shannon}} : $_[0]->{_shannon}); }

sub score { return(wantarray() ? @{$_[0]->{_score}} : $_[0]->{_score}); }

sub ratio { return(wantarray() ? @{$_[0]->{_ratio}} : $_[0]->{_ratio}); }

1;