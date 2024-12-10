package Graphics::Chart::Heatmap;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;

use base qw(Graphics::Chart);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ y             => undef,
                   plotValues    => 0,
                   valueTextSize => 5,
                   roundValues   => 3,
                   _paletteType => "fill" }, \%parameters);

    # Override user-defined settings
    $self->{fill} = "data";
    $self->{colorScale} = "gradient";

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->SUPER::_validate();

    $self->throw("No data label defined for y") if (!defined $self->{y});
    $self->throw("Data label \"" . $self->{y} . "\" does not exist") if (!exists $self->{dataLabels}->{$self->{y}});
    $self->throw("plotValues must be BOOL") if (!isbool($self->{plotValues}));
    
    for (qw(valueTextSize roundValues)) { $self->throw("$_ must be positive") if (!ispositive($self->{$_})); }

}

sub _generateRcode {

    my $self = shift;

    my ($id, $dataLabels, $Rcode);
    $id = $self->{id};
    $dataLabels = $self->_collapseDataLabels();
    $Rcode = "df_$id<-data.frame(data=c(" . join(",", @{$self->{data}}) . ")";
    $Rcode .= ", $_=c(" . $dataLabels->{$_} . ")" for (keys %$dataLabels);
    $Rcode .= ");\n";

    $Rcode .= "df_$id\$$_<-factor(df_$id\$$_, levels=c('" . join("', '", @{$self->{dataLabelSort}->{$_}}) . "'));\n" for (keys %{$self->{dataLabelSort}});

    $Rcode .= "plot_$id<-ggplot(df_$id, aes(x=" . (defined $self->{x} ? $self->{x} : "seq(from=1, to=nrow(df_$id))") .
              ", y=" . $self->{y} . ", fill=data)) + geom_tile()";
    $Rcode .= " + geom_text(aes(label=round(data, " . $self->{roundValues} . ")), color='black', size=" . $self->{valueTextSize} . ")" if ($self->{plotValues});

    $Rcode .= " + " . $self->SUPER::_generateRcode();

    return($Rcode);

}

1;
