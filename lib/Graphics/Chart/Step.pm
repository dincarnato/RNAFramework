package Graphics::Chart::Step;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;

use base qw(Graphics::Chart);

sub new {

    my $class = shift;
    my %parameters = @_;

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ lineThickness => 0.5,
                   _paletteType  => "colour" }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("lineThickness must be positive") if (!ispositive($self->{lineThickness}));

    $self->SUPER::_validate();

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
              ", y=data, colour=" . $self->{fill} . ")) + geom_step(lwd=" . $self->{lineThickness} . ")";

    $Rcode .= " + " . $self->SUPER::_generateRcode();

    return($Rcode);

}

1;
