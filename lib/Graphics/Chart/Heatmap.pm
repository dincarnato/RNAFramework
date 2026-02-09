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
                   cluster       => undef, 
                   _paletteType  => "fill" }, \%parameters);

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
    $self->throw("Invalid cluster value \"" . $self->{cluster} . "\" (allowed: \"rows\", \"columns\", or \"both\")") if (defined $self->{cluster} && $self->{cluster} !~ /^(?:rows|columns|both)$/);
    
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

    if (defined $self->{cluster}) {

        $Rcode .= "samples<-sort(unique(c(df_$id\$x, df_$id\$y)))\n" .
                  "matrix<-matrix(NA, nrow=length(samples), ncol=length(samples), dimnames=list(samples, samples))\n" .
                  "for (i in seq_len(nrow(df_$id))) { matrix[df_$id\$y[i], df_$id\$x[i]] <- df_$id\$data[i]}\n";
        $Rcode .= "row_clust<-hclust(dist(matrix))\n" if ($self->{cluster} ne "columns");
        $Rcode .= "col_clust<-hclust(dist(t(matrix)))\n" if ($self->{cluster} ne "rows");
        
        if ($self->{cluster} eq "both") { $Rcode .= "matrix_clustered<-matrix[row_clust\$order, col_clust\$order]\n"; }
        elsif ($self->{cluster} eq "rows") { $Rcode .= "matrix_clustered<-matrix[row_clust\$order, , drop=FALSE]\n"; }
        else { $Rcode .= "matrix_clustered<-matrix[ , col_clust\$order, drop=FALSE]\n"; }

        $Rcode .= "df_$id<-expand.grid(y=rownames(matrix_clustered), x=colnames(matrix_clustered), KEEP.OUT.ATTRS=FALSE, stringsAsFactors=FALSE)\n" .
                  "df_$id\$data<-as.vector(matrix_clustered)\n" .
                  "df_$id\$x<-factor(df_$id\$x, levels=colnames(matrix_clustered))\n" .
                  "df_$id\$y<-factor(df_$id\$y, levels=rownames(matrix_clustered))\n";

    }

    $Rcode .= "df_$id\$$_<-factor(df_$id\$$_, levels=c('" . join("', '", @{$self->{dataLabelSort}->{$_}}) . "'));\n" for (keys %{$self->{dataLabelSort}});

    $Rcode .= "plot_$id<-ggplot(df_$id, aes(x=" . (defined $self->{x} ? $self->{x} : "seq(from=1, to=nrow(df_$id))") .
              ", y=" . $self->{y} . ", fill=data)) + geom_tile()";
    $Rcode .= " + geom_text(aes(label=round(data, " . $self->{roundValues} . ")), color='black', size=" . $self->{valueTextSize} . ")" if ($self->{plotValues});

    $Rcode .= " + " . $self->SUPER::_generateRcode();

    return($Rcode);

}

1;
