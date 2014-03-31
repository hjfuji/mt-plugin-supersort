#
# Util.pm
#
# 2008/10/20 1.00b1 Beta release
#
# Copyright(c) by H.Fujimoto
#
package SuperSort::Util;

use strict;
use base 'Exporter';

our @EXPORT_OK = qw( load_adjacent_entry left_join_placement serialize_cats );

use MT;
use MT::Plugin;
use MT::Blog;
use MT::Entry;
use MT::Page;
use MT::Category;
use MT::Folder;
use MT::Placement;

sub load_adjacent_entry {
    my ($class_name, $mode, $entry, $blog, $cat) = @_;

    my $adj_entry;
    my (%terms, %args);

    $terms{blog_id} = $blog->id;
    $terms{status} = MT::Entry::RELEASE();
    if (!$cat) {
        # entry in root category
        $terms{order_number} = ($mode eq 'prev')
                             ? [ 0, $entry->order_number ]
                             : [ $entry->order_number, undef ];
        $args{direction} = ($mode eq 'prev')
                         ? 'descend' : 'ascend';
        $args{limit} = 1;
        $args{sort} = 'order_number';
        $args{range} = { order_number => 1 };
        $args{join} = left_join_placement();
    }
    else {
        my $place = MT->model('placement')->load({
                        entry_id => $entry->id,
                        category_id => $cat->id
                    })
            or return;
        my $direction = ($mode eq 'prev') ? 'descend' : 'ascend';
        my $order_number = $place->order_number;
        my $order_range = ($mode eq 'prev')
                          ? [ 0, $order_number ]
                          : [ $order_number, undef ];
        $args{join} = MT->model('placement')->join_on(
                          'entry_id',
                          {
                              category_id => $place->category_id,
                              order_number => $order_range
                          },
                          {
                              sort => 'order_number',
                              direction => $direction,
                              range => { order_number => 1 },
                              limit => 1
                          },
                      );
    }
    $adj_entry = MT->model($class_name)->load(\%terms, \%args);
    return $adj_entry;
}

sub left_join_placement {
    return MT->model('placement')->join_on(
        undef,
        {
            category_id => \'is null',
        },
        {
            type => 'left',
            condition => {
                entry_id => \'= entry_id',
            },
        },
    );
}

sub serialize_cats {
    my ($ser_cats, $cats, $parent) = @_;

    my @sib_cats = grep { $_->parent == $parent } @$cats;
    @$cats = grep { $_->parent != $parent } @$cats;
    @sib_cats = sort { $a->order_number <=> $b->order_number } @sib_cats;
    foreach (@sib_cats) {
        push @$ser_cats, $_->id;
        serialize_cats($ser_cats, $cats, $_->id);
    }
}


1;
