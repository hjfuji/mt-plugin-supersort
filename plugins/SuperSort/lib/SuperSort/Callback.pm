#
# Callback.pm
#
# 2008/10/20 1.00b1 Beta release
# 2011/05/26 1.20b1 Beta release For Movable Type 5
#
# Copyright(c) by H.Fujimoto
#
package SuperSort::Callback;

use strict;

use MT;
use MT::Plugin;
use MT::Category;
use MT::Folder;
use MT::Entry;
use MT::Page;
use MT::Placement;
use MT::Request;

use SuperSort::Util qw( load_adjacent_entry left_join_placement );

use constant DEBUG => 0;

sub pre_save_category {
    my ($class_name, $eh, $app, $cat, $org_cat) = @_;
    my $plugin = MT->component('SuperSort');

    if ($app->param('init_parent')) {
        $cat->parent($app->param('init_parent'));
    }
    my $entry_class_name = ($class_name eq 'category') ? 'entry' : 'page';
    return 1 if (!$plugin->get_config_value('fjss_enabled_sort_' . $entry_class_name, 'blog:' . $cat->blog_id));

    my $req = MT::Request->instance;
    $req->stash('SuperSort::cat_is_new', !$cat->exists);
    return 1;
}

sub post_save_category {
    my ($class_name, $eh, $app, $cat, $org_cat) = @_;
    my $plugin = MT->component('SuperSort');

    my $entry_class_name = ($class_name eq 'category') ? 'entry' : 'page';
    return 1 if (!$plugin->get_config_value('fjss_enabled_sort_' . $entry_class_name, 'blog:' . $cat->blog_id));

    my $req = MT::Request->instance;
    my $is_new = $req->stash('SuperSort::cat_is_new');
    my $class = MT->model($class_name);
    if ($is_new) {
        my $prev_cat;
        $prev_cat = $class->load({ blog_id => $cat->blog_id,
                                   parent => $cat->parent,
                                   id => { not => $cat->id } },
                                 { sort => 'order_number',
                                   direction => 'descend',
                                   limit => 1 });
        my $blog = $app->blog;
        my @old_order = split ',', $blog->meta($class_name . '_order');
        my $is_exist = scalar(grep { $_ == $cat->id } @old_order);
        if ($prev_cat) {
            $cat->order_number($prev_cat->order_number + 1);
        }
        else {
            $cat->order_number(1);
        }
        $cat->save
            or return $app->error($plugin->translate('Save [_1] sort order error.', $class_name));
        if (!$is_exist) {
            my @new_order;
            # first created category
            if (!$prev_cat && !$cat->parent) {
                push @new_order, $cat->id;
            }
            else {
                # if no previous category,
                # then this category places next to parent category
                if (!$prev_cat) {
                    $prev_cat = $class->load($cat->parent);
                }
                # if previous category exists,
                # then this category places next to
                # last of previous category tree
                else {
                    while () {
                        my $last_child = $class->load({ blog_id => $cat->blog_id,
                                                        parent => $prev_cat->id },
                                                      { sort => 'order_number',
                                                        direction => 'descend',
                                                        limit => 1 });
                        last if (!$last_child);
                        $prev_cat = $last_child;
                    }
                }
                foreach (@old_order) {
                    push @new_order, $_;
                    push @new_order, $cat->id if ($_ == $prev_cat->id);
                }
            }
            $blog->meta($class_name . '_order', join(',', @new_order));
            $blog->save
                or return $app->error($plugin->translate('Save [_1] sort order error.', $class_name));
        }
    }
    return 1;
}

sub post_delete_category {
    my ($class_name, $eh, $app, $cat) = @_;
    my $plugin = MT->component('SuperSort');

    my $entry_class = ($class_name eq 'category') ? 'entry' : 'page';
    return 1 if (!$plugin->get_config_value('fjss_enabled_sort_' . $entry_class, 'blog:' . $cat->blog_id));

    my $blog = $app->blog;
    my @order = split ',', $blog->meta($class_name . '_order');
    @order = grep { $_ != $cat->id } @order;
    $blog->meta($class_name . '_order', join(',', @order));
    $blog->save
        or return $app->error($plugin->translate('Save [_1] sort order error.', $class_name));
    return 1;
}

sub pre_save_entry {
    my ($class_name, $eh, $app, $entry, $old_entry) = @_;
    my $plugin = MT->component('SuperSort');

    return 1 if (!$plugin->get_config_value('fjss_enabled_sort_' . $class_name, 'blog:' . $entry->blog_id));

    $plugin->do_log('pre save entry start') if (DEBUG);

    my $req = MT::Request->instance;
    my $blog = MT::Blog->load($entry->blog_id);
    if (!$entry->exists) {
        $req->stash('SuperSort::entry_old_place', []);
        $req->stash('SuperSort::old_adjacent_entries', []);
    }
    else {
        my @places = ();
        my @entries = ();
        _load_places_and_adjacent_entries($plugin, $class_name, \@places, \@entries, $entry);
        $req->stash('SuperSort::entry_old_place', \@places);
        $req->stash('SuperSort::old_adjacent_entries', \@entries);
    }
    return 1;
}

sub post_save_entry {
    my ($class_name, $eh, $app, $entry, $old_entry) = @_;
    my $plugin = MT->component('SuperSort');

    return 1 if (!$plugin->get_config_value('fjss_enabled_sort_' . $class_name, 'blog:' . $entry->blog_id));

    $plugin->do_log('post save entry start') if (DEBUG);

    my $req = MT::Request->instance;
    my @new_places = ();
    _load_places($class_name, \@new_places, $entry);
    my $old_places = $req->stash('SuperSort::entry_old_place') || [];
    my @old_places = @$old_places;

    if (DEBUG) {
        use Data::Dumper;
        $plugin->do_log('post_save_entry : old_place = ' . Dumper(\@old_places) . ', new_place = ' . Dumper(\@new_places));
    }

    my %diff_places;
    map { $diff_places{$_->category_id} = $_ } @new_places;
    map { delete $diff_places{$_->category_id} } @old_places;

    if (DEBUG) {
        use Data::Dumper;
        $plugin->do_log('post_save_entry : diff = ' . Dumper(\%diff_places));
    }

    my $is_entry_saved = 0;
    for my $cat_id (keys %diff_places) {
        my $place = $diff_places{$cat_id};
        if ($place->category_id) {
            # set placement order_number
            my $last_place = MT->model('placement')->load(
                { blog_id => $place->blog_id,
                  category_id => $place->category_id },
                { sort => 'order_number',
                  direction => 'descend',
                  limit => 1 });
            if ($last_place) {
                $place->order_number($last_place->order_number + 1);
            }
            else {
                $place->order_number(1);
            }
            $place->save;
            if (!$is_entry_saved) {
                $entry->order_number(undef);
                $entry->save;
                $is_entry_saved = 1;
            }
        }
        else {
            # set entry order_number
            my @entries = MT->model($entry->class)->load(
                              { 
                                  blog_id => $entry->blog_id,
                              },
                              {
                                  join => left_join_placement(),
                                  sort => 'order_number',
                                  direction => 'descend',
                                  limit => 1
                              }
                          );
            if (scalar @entries) {
                $entry->order_number($entries[0]->order_number + 1);
            }
            else {
                $entry->order_number(1);
            }
            $entry->save;
        }
    }

    my %resave_places = ();
    map { $resave_places{$_->category_id}{new} = $_ } @new_places;
    map { $resave_places{$_->category_id}{old} = $_ } @old_places;
    for my $cat_id (keys %resave_places) {
        if (defined($resave_places{$cat_id}{new}) &&
            defined($resave_places{$cat_id}{old}) &&
            $resave_places{$cat_id}{new}->id !=
            $resave_places{$cat_id}{old}->id) {

            if (DEBUG) {
                use Data::Dumper;
                $plugin->do_log('cat_id = ' . $cat_id . ', new = ' . Dumper($resave_places{$cat_id}{new}) . ', old = ' . Dumper($resave_places{$cat_id}{old}));
            }

            $resave_places{$cat_id}{new}->order_number($resave_places{$cat_id}{old}->order_number);
            $resave_places{$cat_id}{new}->save;
        }
    }

    $plugin->do_log('post save order saved') if (DEBUG);

    # rebuild adjacent entries
    my $do_rebuild = undef;
    if (($entry && $entry->status == MT::Entry::RELEASE()) || 
        ($old_entry && $old_entry->status == MT::Entry::RELEASE())) {
        $do_rebuild = 1;
    }
    if ($plugin->get_config_value('fjss_auto_rebuild_' . $entry->class, 'blog:' . $entry->blog_id) && $do_rebuild) {
        my $old_entries = $req->stash('SuperSort::old_adjacent_entries') || [];
        my @new_entries = ();
        _load_adjacent_entries($plugin, $class_name, \@new_places, \@new_entries, $entry);
        _rebuild_adjacent_entries($plugin, $app, $old_entries, \@new_entries, $entry, $entry->class eq 'page');
    }

    return 1;
}

sub pre_delete_entry {
    my ($eh, $app, $entry) = @_;
    my $plugin = MT->component('SuperSort');

    return 1 if (!$plugin->get_config_value('fjss_enabled_sort_' . $entry->class, 'blog:' . $entry->blog_id) ||
                 !$plugin->get_config_value('fjss_auto_rebuild_after_delete_' . $entry->class, 'blog:' . $entry->blog_id));

    $plugin->do_log('pre delete entry start') if (DEBUG);

    my $req = MT::Request->instance;
    my @places = ();
    my @entries = ();
    _load_places_and_adjacent_entries($plugin, $entry->class, \@places, \@entries, $entry);
    $req->stash('SuperSort::old_adjacent_entries', \@entries);

    return 1;
}
sub post_delete_entry {
    my ($class_name, $eh, $app, $entry) = @_;
    my $plugin = MT->component('SuperSort');

    return 1 if (!$plugin->get_config_value('fjss_enabled_sort_' . $class_name, 'blog:' . $entry->blog_id) ||
                 !$plugin->get_config_value('fjss_auto_rebuild_after_delete_' . $entry->class, 'blog:' . $entry->blog_id));

    $plugin->do_log('post delete entry start') if (DEBUG);

    my $req = MT::Request->instance;
    my $old_entries = $req->stash('SuperSort::old_adjacent_entries') || [];
    _rebuild_adjacent_entries($plugin, $app, $old_entries, [], $entry, 1);
}

sub _rebuild_adjacent_entries {
    my ($app, $old_entries, $new_entries, $entry, $is_adj_rebuild) = @_;
    my $plugin = MT->component('SuperSort');

    my $blog = MT::Blog->load($entry->blog_id);
    my %entries;

    $plugin->do_log('rebuild_entries start') if (DEBUG);

    # list entries to rebuild
    map { $entries{$_->id} = $_ } @$old_entries;
    map { $entries{$_->id} = $_ } @$new_entries;

    if (DEBUG) {
        use Data::Dumper;
        $plugin->do_log('rebuild_entries (before data adajacent remove) = ' . join(',', keys %entries));
    }

    if (!$is_adj_rebuild) {
        # delete date_ordered adjacent entries
        my $date_prev_entry = $entry->previous;
        delete $entries{$date_prev_entry->id} if $date_prev_entry;
        my $date_next_entry = $entry->next;
        delete $entries{$date_next_entry->id} if $date_next_entry;
    }

    if (DEBUG) {
        use Data::Dumper;
        $plugin->do_log('rebuild_entries = ' . join(',', keys %entries));
    }

    # rebuild entries
    for my $entry_id (keys %entries) {
        my $adj_entry = $entries{$entry_id};
        $app->rebuild_entry(Entry => $adj_entry, Blog => $blog);
    }
    return 1;
}

sub _load_places {
    my ($class_name, $places, $entry) = @_;

    @$places = MT::Placement->load({ entry_id => $entry->id });
    if (!scalar(@$places)) {
        my $place = MT::Placement->new;
        $place->category_id(0);
        push @$places, $place;
    }
}

sub _load_adjacent_entries {
    my ($class_name, $places, $entries, $entry) = @_;
    my $plugin = MT->component('SuperSort');

    $plugin->do_log('load adjacent entries start') if (DEBUG);

    my $blog = MT::Blog->load($entry->blog_id);

    for my $place (@$places) {
        if (!$place->category_id) {
            my $prev_entry = load_adjacent_entry($class_name, 'prev', $entry, $blog, undef);
            push @$entries, $prev_entry if ($prev_entry);

            if (DEBUG) {
                use Data::Dumper;
                my $msg = 'loaded prev entry : org = ' . $entry->id . ', order_number = ' . $entry->order_number;
                if ($prev_entry) {
                    $msg .= ', prev = ' . $prev_entry->id;
                }
                $plugin->do_log($msg);
            }

            my $next_entry = load_adjacent_entry($class_name, 'next', $entry, $blog, undef);
            push @$entries, $next_entry if ($next_entry);

            if (DEBUG) {
                use Data::Dumper;
                my $msg = 'loaded next entry : org = ' . $entry->id . ', order_number = ' . $entry->order_number;
                if ($next_entry) {
                    $msg .= ', next = ' . $next_entry->id;
                }
                $plugin->do_log($msg);
            }

        }
        else {
            my $cat_class_name = ($class_name eq 'entry') ? 'category' : 'folder';
            my $cat_class = MT->model($cat_class_name);
            my $cat = $cat_class->load($place->category_id);
            my $prev_entry = load_adjacent_entry($class_name, 'prev', $entry, $blog, $cat);
            push @$entries, $prev_entry if ($prev_entry);

            if (DEBUG) {
                use Data::Dumper;
                my $msg = 'loaded prev entry : cat = ' . $cat->label . ', org = ' . $entry->id . ', order_number = ' . $place->order_number;
                if ($prev_entry) {
                    $msg .= ', prev = ' . $prev_entry->id;
                }
                $plugin->do_log($msg);
            }

            my $next_entry = load_adjacent_entry($class_name, 'next', $entry, $blog, $cat);
            push @$entries, $next_entry if ($next_entry);

            if (DEBUG) {
                use Data::Dumper;
                my $msg = 'loaded next entry : cat = ' . $cat->label . ', org = ' . $entry->id . ', order_number = ' . $place->order_number;
                if ($next_entry) {
                    $msg .= ', next = ' . $next_entry->id;
                }
                $plugin->do_log($msg);
            }

        }
    }
}

sub _load_places_and_adjacent_entries {
    my ($class_name, $places, $entries, $entry) = @_;
    my $plugin = MT->component('SuperSort');

    _load_places($class_name, $places, $entry);
    _load_adjacent_entries($plugin, $class_name, $places, $entries, $entry);
}

sub bulk_save_categories {
    my ($eh, $app, $cats) = @_;
    my $plugin = MT->component('SuperSort');

    return 1 unless ($cats && scalar @$cats);
    my $class = $cats->[0]->class;
    my $result = _recursive_bulk_save_categories($cats, 0);
    unless ($result) {
        return $app->error($plugin->translate('Save [_1] sort order error.', $class));
    }
    return 1;
}

sub _recursive_bulk_save_categories {
    my ($cats, $parent) = @_;

    my @sib_cats = grep { $_->parent == $parent } @$cats;
    my $i = 1;
    foreach (@sib_cats) {
        $_->order_number($i);
        $_->save or return;
        return if (!_recursive_bulk_save_categories($cats, $_->id));
        $i++;
    }
    return 1;
}

1;
