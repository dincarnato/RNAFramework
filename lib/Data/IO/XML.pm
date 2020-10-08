package Data::IO::XML;

use strict;
use Core::Utils;

use base qw(Data::IO);

sub new {
    
    my $class = shift;
    my %parameters = @_ if (@_);
    
    my $self = $class->SUPER::new(%parameters);
    $self->_init({ heading       => 1,
                   autoclear     => 1,
                   autoclose     => 1,
                   indent        => 0,
                   _indent       => 0,
                   _xml          => undef,
                   _tags         => [],
                   _text         => 0 }, \%parameters);
    
    if ($class =~ m/^Data::IO::XML::\w+$/) {
        
        $self->_validate();
        $self->_openfh();
        
        binmode($self->{_fh}, ":encoding(utf-8)");
        
        return($self);
        
    }
    else {
        
        my ($module, $object);
        $module = ref($self) . "::" . ($self->mode() eq "r" ? "Read" : "Write");
        
        $self->loadPackage($module);
        $object = $module->new(%parameters);
        
        return($object);
        
    }
    
}

1;
