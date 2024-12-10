package Graphics::Chart::Density;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;

use base qw(Graphics::Chart);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ lineColor     => "black",
                   lineThickness => 0.5,
                   lineType      => "solid",
                   alpha         => 0.5,
                   _paletteType  => "fill" }, \%parameters);

    $self->{x} = "data";

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->SUPER::_validate();

    for (qw(lineThickness alpha)) { $self->throw("$_ must be positive") if (!ispositive($self->{$_})); }

    $self->throw("Accepted lineType values are: \"" . join("\", \"", qw(twodash dotdash longdash dashed
                                                                        dotted solid blank)) . "\"") if ($self->{lineType} !~ m/^(?:(?:two|dot|long)dash|dashed|dotted|solid|blank)$/);

}

sub _generateRcode {

    my $self = shift;

    my ($id, $dataLabels, $Rcode);
    $id = $self->{id};
    $dataLabels = $self->_collapseDataLabels();
    $Rcode = "df_$id<-data.frame(data=c(" . join(",", @{$self->{data}}) . ")";
    $Rcode .= ", $_=c(" . $dataLabels->{$_} . ")" for (keys %$dataLabels);
    $Rcode .= ");\n";

    $Rcode .= "df_$id\$" . $self->{x} . "<-as.numeric(df_$id\$" . $self->{x} . ");\n" if (defined $self->{x});

    $Rcode .= "plot_$id<-ggplot(df_$id, aes(x=data, fill=" . $self->{fill} . "))";
    $Rcode .= " + geom_density(color='" . $self->{lineColor} . "', lwd=" . $self->{lineThickness} . ", linetype='" . $self->{lineType} . "', alpha=" . $self->{alpha} . ")";

    $Rcode .= " + " . $self->SUPER::_generateRcode();

    return($Rcode);

}

1;
