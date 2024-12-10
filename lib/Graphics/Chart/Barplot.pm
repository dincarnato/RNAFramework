package Graphics::Chart::Barplot;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;

use base qw(Graphics::Chart);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ stdev         => undef,
                   errorBarWidth => 0.3,
                   plotValues    => 0,
                   valueTextSize => 3,
                   roundValues   => 3,
                   _paletteType  => "fill" }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->SUPER::_validate();

    $self->throw("Data label \"" . $self->{stdev} . "\" does not exist") if (defined $self->{stdev} && !exists $self->{dataLabels}->{$self->{stdev}});
    $self->throw("plotValues must be BOOL") if (!isbool($self->{plotValues}));
    
    for (qw(valueTextSize roundValues errorBarWidth)) { $self->throw("$_ must be positive") if (!ispositive($self->{$_})); }

    if (exists $self->{dataLabelType}->{data}) {
        
        $self->warn("Label \"data\" cannot be set to \"character\", falling back to \"numeric\"") if ($self->{dataLabelType}->{data} eq "character");

        delete($self->{dataLabelType}->{data});

    }

}

sub _generateRcode {

    my $self = shift;

    my ($id, $dataLabels, $Rcode);
    $id = $self->{id};
    $dataLabels = $self->_collapseDataLabels();
    $Rcode = "df_$id<-data.frame(data=c(" . join(",", @{$self->{data}}) . ")";
    $Rcode .= ", $_=c(" . $dataLabels->{$_} . ")" for (keys %$dataLabels);
    $Rcode .= ");\n";

    $Rcode .= "df_$id\$data<-as.numeric(df_$id\$data);\n";
    $Rcode .= "df_$id\$$_<-factor(df_$id\$$_, levels=c('" . join("', '", @{$self->{dataLabelSort}->{$_}}) . "'));\n" for (keys %{$self->{dataLabelSort}});

    $Rcode .= "plot_$id<-ggplot(df_$id, aes(x=" . (defined $self->{x} ? $self->{x} : "seq(from=1, to=nrow(df_$id))") .
              ", y=data, fill=" . $self->{fill} . ")) + geom_bar(stat='identity'";
    $Rcode .= ", position=" . ($self->{groupMethod} eq "dodge" ? "position_dodge(width=0.9)" : "'stack'") . ")";

    if ($self->{stdev} && $self->{groupMethod} ne "stack") {

        $Rcode .= " + geom_errorbar(aes(ymin=data-as.numeric(" . $self->{stdev} . "), ymax=data+as.numeric(" . $self->{stdev} . "))" .
                  ", width=" . $self->{errorBarWidth} . ", position=position_dodge(width=0.9))";

    }

    if ($self->{plotValues}) {

        $Rcode .= " + geom_text(aes(label=ifelse(data==0, NA, round(data, " . $self->{roundValues} . "))";
        $Rcode .= ", y=data+" . ($self->{stdev} ? "as.numeric(" . $self->{stdev} . ")+0.01" : "0.01") if ($self->{groupMethod} eq "dodge");
        $Rcode .= "), position=" . ($self->{groupMethod} eq "dodge" ? "position_dodge(width=0.9), vjust=0" : "position_stack(vjust=0.5)") .
                  ", size=" . $self->{valueTextSize} . ")";

    }

    $Rcode .= " + " . $self->SUPER::_generateRcode();

    return($Rcode);

}

1;
