#!/usr/bin/perl

package Cluster::Kmeans;

use strict;
use Core::Mathematics qw(:all);
use Core::Utils;
use List::Util qw(shuffle);
use Data::Dumper;

use base qw(Core::Base);

use constant MINDIST => 1e308;

sub new {

    my $class = shift;
    my %parameters = @_ if (@_);

    my $self = $class->SUPER::new(%parameters);
    $self->_init({ data          => [],
                   distfunc      => \&_euclidean,
                   centroidfunc  => \&_vecmean,
                   kmin          => 1,
                   kmax          => undef,
                   maxiterations => 20,
                   refine        => 0,
                   miniBatch     => 0,
                   batchSize     => 1000,
                   samplings     => 10,
                   _clusters     => [],
                   _centroids    => [],
                   _iterations   => 0 }, \%parameters);

    $self->_validate();

    return($self);

}

sub _validate {

    my $self = shift;

    $self->throw("Distance function must be a CODE reference") if (defined $self->{distfunc} &&
																   ref($self->{distfunc}) ne "CODE");
    $self->throw("miniBatch parameter must be BOOL") if (!isbool($self->{miniBatch}));

    $self->{kmin} ||= 1;
    $self->{kmax} = @{$self->{data}} if (!$self->{kmax} ||
                                         $self->{kmax} > @{$self->{data}});

    if ($self->{miniBatch}) {

        $self->{maxiterations} = 1;
        $self->{batchSize} = @{$self->{data}} if ($self->{batchSize} > @{$self->{data}});

    }

}

sub clusters { return(wantarray() ? @{$_[0]->{_clusters}} : $_[0]->{_clusters}); }

sub centroids { return(wantarray() ? @{$_[0]->{_centroids}} : $_[0]->{_centroids}); }

sub _refine {

    my $self = shift;

    for (my $i = 0; $i < @{$self->{_clusters}}; $i++) {

        #next if (@{$self->{_clusters}->[$i]} != 1);

        my ($mindist, $dist, $closeto, @dists);
        $mindist = MINDIST;
        @dists = map { $self->{distfunc}->($self->{_centroids}->[$i], $self->{_centroids}->[$_]) } 0 .. $#{$self->{_centroids}};
        $dists[$i] = MINDIST; # Masks its own centroid
        $dist = min(@dists);

        if ($dist < $mindist) {

            $mindist = $dist;
            $closeto = argmin(@dists);

            push(@{$self->{_clusters}->[$closeto]}, @{$self->{_clusters}->[$i]});
            $self->{_centroids}->[$closeto] = $self->{centroidfunc}->(@{$self->{_clusters}->[$closeto]});
            splice(@{$self->{_clusters}}, $i, 1);
            splice(@{$self->{_centroids}}, $i, 1);

            $i--;

        }

    }

}

sub cluster {

    my $self = shift;
    my $k = shift || 0;
    my $initialCentroids = shift || [];

    $self->{_iterations} = 0;
    $k = @{$initialCentroids} if (@{$initialCentroids});

    if (!$k) {

        if ($self->{kmin} == 1 &&
            $self->{kmax} == 1) { $k = 1; }
        else {

            # Temporarily disables refinement
            my $refine = $self->{refine};
            $self->{refine} = 0;

            $k = $self->_silhouette();
            undef($self->{_centroids});
            undef($self->{_clusters});

            $self->{refine} = $refine;

        }

    }

    my (@centroids);

    if (@{$initialCentroids}) { @centroids = @{$initialCentroids}; }
    else {

        my ($nelements, $ntries, $distsum, $clusters,
            @data, @dist);
        @data = @{$self->{data}};
        $nelements = @data;
        $ntries = int(2 + log($k));
        @centroids = ($data[rand(int($nelements))]);
        @dist = map { $self->{distfunc}->($_, $centroids[0]) ** 2 } @data;
        $distsum = sum(@dist);

        for (0 .. $k - 2) {

            my ($bestdistsum, $besti) = (-1, -1);

            for (0 .. $ntries - 1) {

                my ($rand, $lasti, $tmpdistsum, @tmpdist);
                $rand = rand() * $distsum;
                $lasti = 0;

                for my $i (0 .. $nelements - 1) {

                    $lasti = $i;

                    if ($rand <= $dist[$i]) { last; }
                    else { $rand -= $dist[$i]; }

                }

                @tmpdist = map { min($dist[$_], $self->{distfunc}->($data[$_],$ data[$lasti]) ** 2) } 0 .. $nelements - 1;
                $tmpdistsum = sum(@tmpdist);

                if ($bestdistsum < 0 ||
                    $tmpdistsum < $bestdistsum) {

                    $bestdistsum = $tmpdistsum;
                    $besti = $lasti;

                }

            }

            $distsum = $bestdistsum;
            push(@centroids, $data[$besti]);
            @dist = map { min($dist[$_], $self->{distfunc}->($data[$_], $data[$besti]) ** 2) } 0 .. $nelements - 1;

        }

    }

    # MiniBatch Kmeans
    if ($self->{miniBatch}) {

        for (0 .. $self->{samplings} - 1) {

            my ($clusters, $centroids, @batch);
            @batch = (shuffle(@{$self->{data}}))[0 .. $self->{batchSize} - 1];
            ($clusters, $centroids) = $self->_kmeans(\@centroids, \@batch);
            @centroids = @{$centroids};

            $self->{_iterations} = 0;

        }

    }

    ($self->{_clusters}, $self->{_centroids}) = $self->_kmeans(\@centroids);

    $self->_refine() if ($self->{refine});

}

sub _kmeans {

    my $self = shift;
    my $centroids = shift if (@_);
    my $data = shift || $self->{data};

    $self->{_iterations}++;

    my ($oldcentroids, $pass, @clusters);
    $pass = 1;
    $oldcentroids = clonearrayref($centroids);
    @clusters = map { [] } 0 .. $#{$centroids};

    foreach my $datapoint (@{$data}) {

        my ($mindist, $dist, $closeto, @dists);
        $mindist = MINDIST;
        @dists = map { $self->{distfunc}->($datapoint, $centroids->[$_]) } 0 .. $#{$centroids};
        $dist = min(@dists);

        if ($dist < MINDIST) {

            $mindist = $dist;
            $closeto = argmin(@dists);
            push(@{$clusters[$closeto]}, $datapoint);

        }
        else {

            # No cluster is suitable for adding the point, so we add a new cluster
            # Note: this happens with custom distance functions, in case the function
            # returns 1e308 as a distance (helpful to get automatic cluster number identification)

            push(@{$centroids}, $datapoint);
            push(@{$oldcentroids}, $datapoint);
            push(@clusters, [ $datapoint ]);

        }

    }

    # Check, if one cluster is empty, then lower the number of clusters (and centroids)
    for (my $i = 0; $i< @clusters; $i++) {

        if (!scalar(@{$clusters[$i]})) {

            splice(@clusters, $i, 1);
            splice(@{$centroids}, $i, 1);
            splice(@{$oldcentroids}, $i, 1);
            $i--;

            $pass = 1;

        }

    }

    for my $i (0 .. $#{$centroids}) {

        my ($deviance);
        $centroids->[$i] = $self->{centroidfunc}->(@{$clusters[$i]});
        $deviance = $self->{distfunc}->($centroids->[$i], $oldcentroids->[$i]);

        $pass = 0 if ($deviance > 0.0);

    }

    return(\@clusters, $centroids) if ($self->{_iterations} == $self->{maxiterations} || $pass == 1);

    return($self->_kmeans($centroids));

}

#sub _elbow {
#
#    my $self = shift;
#
#    my (@vars);
#
#    foreach my $k ($self->{kmin} .. $self->{kmax}) {
#
#        my ($centroids, $clusters, $var);
#        ($centroids, $clusters) = $self->cluster($k);
#
#        # Clusters have been reduced during kmeans, so we are at optimal
#        if ($k != @{$clusters}) {
#
#            $self->{kmax} = @{$clusters};
#
#            return($self->{kmax});
#
#        }
#
#        foreach my $c (0 .. $#{$clusters}) {
#
#            my $mean = _vecmean(@{$clusters->[$c]});
#            $var += ($self->{distfunc}->($clusters->[$c]->[$_], $mean)) ** 2 for (0 .. $#{$clusters->[$c]});
#
#        }
#
#        push(@vars, $var);
#
#    }
#
#}

sub _silhouette {

    my $self = shift;

    my ($lastk, $lastsil);

    foreach my $k ($self->{kmin} .. $self->{kmax}) {

        next if ($k == 1);

        my ($centroids, $clusters, $sil, @csils);
        $self->cluster($k);
        ($centroids, $clusters) = ($self->{_centroids}, $self->{_clusters});

        # Clusters have been reduced during kmeans, so we are at optimal
        if ($k != @{$clusters}) {

            $self->{kmax} = @{$clusters};

            return($self->{kmax});

        }

        foreach my $c (0 .. $#{$clusters}) {

            if (@{$clusters->[$c]} == 1) {

                push(@csils, 0);

                next;

            }

            my (@a, @b);

            foreach my $i (0 .. $#{$clusters->[$c]}) {

                my (@toa, @tob);
                @toa = map { $self->{distfunc}->($clusters->[$c]->[$i], $clusters->[$c]->[$_]) } grep { $_ != $i } 0 .. $#{$clusters->[$c]};

                foreach my $altc (0 .. $#{$clusters}) {

                    next if ($altc == $c);

                    push(@tob, mean(map { $self->{distfunc}->($clusters->[$c]->[$i], $clusters->[$altc]->[$_]) } 0 .. $#{$clusters->[$altc]}));

                }

                push(@a, mean(@toa));
                push(@b, min(@tob));

            }

            push(@csils, $a[$_] == $b[$_] ? 0 : ($b[$_] - $a[$_]) / max($a[$_], $b[$_])) for (0 .. $#a);

        }

        $sil = mean(@csils);

        if ($lastsil < $sil) {

            $lastsil = $sil;
            $lastk = $k;

        }

    }

    return($lastk || 1);

}

sub _euclidean {

    my ($x, $y) = @_;

    my $sumsq = 0;

    $sumsq += ($x->[$_] - $y->[$_]) ** 2 for (0 .. $#{$x});

    return($sumsq ** 0.5);

}

sub _vecmean {

    my @values = @_;

    my (@avg);

    return($values[0]) if (@values == 1);

    for my $i (0 .. $#{$values[0]}) {

        for my $j (0 .. $#values) { push(@{$avg[$i]}, $values[$j]->[$i]); }

    }

    @avg = map { mean(@{$_}) } @avg;

    return(\@avg);

}

1;
