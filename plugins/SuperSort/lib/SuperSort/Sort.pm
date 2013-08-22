#
# Sort.pm
#
# 2008/10/20 1.00b1 Beta release
# 2011/05/29 1.20b1 For Movable Type 5.1 Beta release
# 2013/08/04 1.20b3 For Movable Tyep 6 Beta1
#
# Copyright(c) by H.Fujimoto
#
package SuperSort::Sort;

use strict;

use MT;
use MT::Plugin;
use MT::Blog;
use MT::Entry;
use MT::Page;
use MT::Category;
use MT::Folder;
use MT::Placement;
use SuperSort::Util qw ( left_join_placement );

use MT::Util qw( encode_js format_ts );
use MT::I18N;

use JSON;

use constant PER_LOAD => 100;
use constant PER_SAVE => 100;

# start sort
sub start_sort_order {
    my $app = shift;
    my $plugin = MT->component('SuperSort');
    my %param;

    my $blog_id = $app->param('blog_id');
    if (!$blog_id) {
        $app->redirect($app->uri(mode => 'dashboard', args => { blog_id => 0 }));
    }
    my $blog = MT::Blog->load($blog_id);
    my $class_name = $app->param('type') || 'category';
    my $cat_plural = ($class_name eq 'category') ? 'categories' : 'folders';
    my $entry_plural = ($class_name eq 'category') ? 'entries' : 'pages';

    # count root categories / entries count
    my $class = MT->model($class_name);
    my $cat_count = $class->count({ blog_id => $blog_id,
                                    parent => 0 });
    my $entry_class_name = ($class_name eq 'category') ? 'entry' : 'page';
    my $entry_count = MT->model($entry_class_name)->count(
                          {
                              blog_id => $blog_id
                          },
                          {
                              join => left_join_placement(),
                          },
                      );

    # build page
    $param{blog_id} = $blog_id;
    $param{class_name} = $class_name;
    $param{entry_class_name} = $entry_class_name;
    $param{cat_single} = $plugin->translate($class_name);
    $param{entry_single} = $plugin->translate($entry_class_name);
    $param{cat_plural} = $plugin->translate($cat_plural);
    $param{entry_plural} = $plugin->translate($entry_plural);
    $param{cat_count} = $cat_count;
    $param{entry_count} = $entry_count;
    $param{can_sort} = ($cat_count > 0 || $entry_count > 0);
    $param{per_load} = PER_LOAD;
    $param{saved} = $app->param('saved');
    my $delete_type = $app->param('delete_type');
    $param{delete_type} = $plugin->translate($delete_type) if ($delete_type);
    $param{blog_single} = $plugin->translate($blog->class);
    $param{drag_drop} = $plugin->get_config_value('fjss_enabled_drag_and_drop', 'blog:' . $blog_id) ? 'true' : 'false';
    my $tmpl = $plugin->load_tmpl('sort.tmpl');
    $tmpl->text($plugin->translate_templatized($tmpl->text));
    $app->build_page($tmpl, \%param);
}

# load categories
sub load_categories {
    my $app = shift;
    my $plugin = MT->component('SuperSort');
    my %param;

    my $blog_id = $app->param('blog_id');
    my $node = $app->param('node');
    my $parent_id = $app->param('parent_id');
    my $class_name = $app->param('type') || 'category';
    my $class = MT->model($class_name);
    my $entry_class_name = ($class_name eq 'category') ? 'entry' : 'page';
    my $entry_class = MT->model($entry_class_name);
    my ($cat_count, $entry_count);

    # load child categories / folders of category / folder $parent_id
    my @categories = $class->load({ blog_id => $blog_id,
                                    parent => $parent_id },
                                  { sort => 'order_number',
                                    direction => 'ascend' });
    my @cat_data;
    for my $category (@categories) {
        my @args = ({ blog_id => $blog_id },
                    { 'join' => [ 'MT::Placement', 'entry_id',
                                  { category_id => $category->id } ] });
        $entry_count = scalar $entry_class->count(@args);
        $cat_count = $class->count({ blog_id => $blog_id,
                                        parent => $category->id });
        my $cat_data = {
            text => $category->label,
            cid => $category->id,
            id => $node . '/cat_' . $category->id,
            cls => 'folder',
            entry_count => $entry_count,
            cat_count => $cat_count,
            parent_cat => $parent_id,
        };
        push @cat_data, $cat_data;
    }
    $app->{no_print_body} = 1;
    $app->send_http_header("text/javascript; charset=utf-8");
    $app->print_encode(to_json(\@cat_data));
}

# load entries
sub load_entries {
    my $app = shift;
    my $plugin = MT->component('SuperSort');
    my %param;

    # get parameter
    my $blog_id = $app->param('blog_id');
    my $blog = MT->model('blog')->load($blog_id) ||
               MT->model('website')->load($blog_id);
    my $class_name = $app->param('type') || 'category';
    my $parent_id = $app->param('parent_id');
    my $offset = $app->param('offset');
    my $node = $app->param('node');
    my $entry_class_name = ($class_name eq 'category') ? 'entry' : 'page';
    my $entry_class = MT->model($entry_class_name);

    # load entries
    my @entries;
    my (%terms, %args);
    $terms{blog_id} = $blog_id;
    $args{offset} = $offset;
    $args{limit} = PER_LOAD;

    if ($parent_id == 0) {
        $args{join} = left_join_placement();
        $args{sort} = 'order_number';
        $args{direction} = 'ascend';
    }
    else {
        $args{join} = MT->model('placement')->join_on(
            'entry_id',
            { category_id => $parent_id },
            { sort => 'order_number',
              direction => 'ascend' }
        );
    }
    @entries = $entry_class->load(\%terms, \%args);

    # count category numbers of each entries
    my @eids = map { $_->id } @entries;
    my $place_counts_iter = MT->model('placement')->count_group_by(
        { entry_id => \@eids },
        { group => [ 'entry_id' ] }
    );
    my %place_counts;
    while (my ($count, $entry_id) = $place_counts_iter->() ) {
        $place_counts{$entry_id} = $count;
    }
    my @entry_data;
    for my $entry (@entries) {
        my $title = $entry->title;
        $title = $plugin->translate('No title') . '(ID:' . $entry->id . ')'
            if (!$title);
        push @entry_data, {
            id => $node . '/entry_' . $entry->id,
            eid => $entry->id,
            parent_cat => $parent_id,
            text => $title,
            cls => 'file',
            leaf => 'true',
            date => format_ts("%x %X", $entry->authored_on, $blog),
            author => $entry->author->name,
            permalink => $entry->permalink,
            cat_count => $place_counts{$entry->id} || 0,
            status => $entry->status,
        };
    }

    $app->{no_print_body} = 1;
    $app->send_http_header("text/javascript; charset=utf-8");
    $app->print_encode(to_json(\@entry_data));
}

# save start
sub save_start {
    my $app = shift;
    my $plugin = MT->component('SuperSort');
    my %param;

    my $blog_id = $app->param('blog_id');
    my $class_name = $app->param('type') || 'category';
    my $entry_class_name = ($class_name eq 'category') ? 'entry' : 'page';
    my $cat_plural = ($class_name eq 'category') ? 'categories' : 'folders';
    my $entry_plural = ($class_name eq 'category') ? 'entries' : 'pages';

    $param{blog_id} = $blog_id;
    $param{class_name} = $class_name;
    $param{cat_single} = $plugin->translate($class_name);
    $param{entry_single} = $plugin->translate($entry_class_name);
    $param{cat_plural} = $plugin->translate($cat_plural);
    $param{entry_plural} = $plugin->translate($entry_plural);
    $param{per_save} = PER_SAVE;

    my $tmpl = $plugin->load_tmpl('save.tmpl');
    $tmpl->text($plugin->translate_templatized($tmpl->text));
    $app->build_page($tmpl, \%param);
}

# save moved data
sub save_moved_data {
    my $app = shift;
    my $plugin = MT->component('SuperSort');

    # initialize
    my $moved_json = $app->param('md');
    my $blog_id = $app->param('blog_id');
    my $cat_class_name = $app->param('class');
    my $entry_class_name = ($cat_class_name eq 'category') ? 'entry' : 'page';
    my $cat_class = MT->model($cat_class_name);
    my $entry_class = MT->model($entry_class_name);

    # convert json to hash reference
    my $moved_data = [];
    if ($moved_json ne 'undefind') {
        $moved_data = from_json($moved_json);
        if (ref $moved_data ne 'ARRAY') {
            $moved_data = [ $moved_data ];
        }

#{
#use Data::Dumper;
#$plugin->do_log('json = ' . $moved_json . ', converted json = ' . Dumper($moved_data));
#}

    }

    my $saved_count = 0;
    eval {
        for my $moved (@$moved_data) {
            my $new_cat_id = $moved->{new_cat};
            my $old_cat_id = $moved->{old_cat};

            # move category / folder
            if ($moved->{type} eq 'category') {
                my $cat = $cat_class->load($moved->{id});
                $cat->parent($new_cat_id);
                $cat->save or die;

#{
#    $plugin->do_log("move $cat_class_name " . $moved->{id} . "(" . $cat->label . ") from $old_cat_id to $new_cat_id");
#}

            }

            # move entry / page
            elsif ($moved->{type} eq 'entry') {
                my $entry_id = $moved->{id};
                # move from sub category / folder
                if ($old_cat_id) {
                    my $place =
                        MT::Placement->load({ entry_id => $entry_id,
                                              category_id => $old_cat_id });
                    # move to other sub category / folder
                    if ($new_cat_id) {
                        $place->category_id($new_cat_id);
                        $place->save or die;

#{
#    my $entry = MT::Entry->load($entry_id);
#    $plugin->do_log("move $entry_class_name $entry_id(" . $entry->title . ") from cat $old_cat_id to $new_cat_id");
#}

                    }
                    # move to root category / folder
                    else {
                        $place->remove;

#{
#    my $entry = MT::Entry->load($entry_id);
#    $plugin->do_log("move $entry_class_name $entry_id(" . $entry->title . ") from cat $old_cat_id to root");
#}

                    }
                }

                # move from root category / folder
                elsif (!$old_cat_id && $new_cat_id) {
                    # create MT::Placement
                    my $place = MT::Placement->new;
                    $place->blog_id($blog_id);
                    $place->entry_id($entry_id);
                    $place->category_id($new_cat_id);
                    $place->is_primary(1);
                    $place->save or die;

#{
#    my $entry = MT::Entry->load($entry_id);
#    $plugin->do_log("move $entry_class_name $entry_id(" . $entry->title . ") from root to $new_cat_id");
#}

                }
            }
            $saved_count++;
        }
    };

    my $msg = ($@) ? "error $saved_count" : 'ok';
    $app->{no_print_body} = 1;
    $app->send_http_header("text/plain; charset=utf-8");
    $app->print_encode($msg);
}

sub save_cat_order {
    my $app = shift;
    my $plugin = MT->component('SuperSort');

    my $blog_id = $app->param('blog_id');
    my $parent_id = $app->param('parent_id');
    my $class_name = $app->param('class');
    my $class = MT->model($class_name);
    my $order_json = $app->param('order');

#    $plugin->do_log("order_json = $order_json");

    # save sort order of categories
    my $order = [];
    if ($order_json ne 'undefind') {
        $order = from_json($order_json);
        if (ref $order ne 'ARRAY') {
            $order = [ $order ];
        }
    }

    my $i = 1;
    eval {
        for my $cat_id (@$order) {

# $plugin->do_log("class = $class, parent_id = $parent_id, cat_id = $cat_id");

            my $cat = $class->load($cat_id);
            $cat->order_number($i);
            $cat->save or die;
            $i++;
        }
    };

    my $msg = ($@) ? "error " . ($i - 1) : 'ok';
    $app->{no_print_body} = 1;
    $app->send_http_header("text/plain; charset=utf-8");
    $app->print_encode($msg);
}

sub save_entry_order {
    my $app = shift;
    my $plugin = MT->component('SuperSort');

    my $blog_id = $app->param('blog_id');
    my $parent_id = $app->param('parent_id');
    my $class_name = $app->param('class');
    my $entry_class_name = ($class_name eq 'category') ? 'entry' : 'page';
    my $class = MT->model($entry_class_name);
    my $order_json = $app->param('order');
    my $offset = $app->param('offset');

#    $plugin->do_log("order_json = $order_json");

    # save sort order of categories
    my $order = [];
    if ($order_json ne 'undefind') {
        $order = from_json($order_json);
        if (ref $order ne 'ARRAY') {
            $order = [ $order ];
        }
    }

    my $i = 1;
    eval {
        # entry of root category / folder
        if ($parent_id == 0) {
            for my $entry_id (@$order) {

#        $plugin->do_log("class = $class, parent_id = $parent_id, entry_id = $entry_id");

                my $entry = $class->load($entry_id);
                $entry->order_number($offset + $i);
                $entry->save or die;
                $i++;
            }
        }
        # entry of sub category / folder
        else {
            for my $entry_id (@$order) {

#        $plugin->do_log("class = $class, parent_id = $parent_id, entry_id = $entry_id");

                my $place = MT::Placement->load({ entry_id => $entry_id,
                                                  category_id => $parent_id });
                $place->order_number($offset + $i);
                $place->save or die;
                $i++;
            }
        }
    };

    my $msg = ($@) ? "error " . ($i - 1) : 'ok';
    $app->{no_print_body} = 1;
    $app->send_http_header("text/plain; charset=utf-8");
    $app->print_encode($msg);
}

# select category
sub select_category {
    my $app = shift;
    my $plugin = MT->component('SuperSort');
    my %param;

    # load category data
    my $blog_id = $app->param('blog_id');
    my $cat_ids_str = $app->param('cat_ids');
    my @cat_ids = split ',', $cat_ids_str;
    my $ptr = 0;
    my %cat_ids = ();
    map { $cat_ids{$_} = $ptr++; } @cat_ids;

    my $class_name = $app->param('type');
    my $class = MT->model($class_name);
    my @cats = $class->load({ blog_id => $blog_id,
                              id => \@cat_ids });
    my @cat_data;
    for (my $i = 0; $i < scalar(@cats); $i++) {
        my $cat = $cats[$i];
        $cat_data[$cat_ids{$cat->id}] = 
            { cat_id => $cat->id,
              cat_label => $cat->label };
    }

    # show page
    $param{blog_id} = $blog_id;
    $param{class_name} = $class_name;
    $param{cat_single} = $plugin->translate($class_name);
    $param{cat_data} = \@cat_data;
    my $tmpl = $plugin->load_tmpl('select_cat.tmpl');
    $tmpl->text($plugin->translate_templatized($tmpl->text));
    $app->build_page($tmpl, \%param);
}

# get child categories
sub get_child_categories {
    my $app = shift;
    my $plugin = MT->component('SuperSort');

    my $id = $app->param('id');
    my $blog_id = $app->param('blog_id');
    my $class_name = $app->param('type');
    my $class = MT->model($class_name);
    my $cat = $class->load($id)
                  or return $app->error($plugin->translate('Delete [_1] error.', $class_name));
    my $ids = [ $cat->id ];
    _get_descendant_category_ids($ids, $cat);
    $app->{no_print_body} = 1;
    $app->send_http_header("text/javascript; charset=utf-8");
    $app->print_encode('{"ids":[' . (join ',', @$ids) . ']}');
}

sub _get_descendant_category_ids {
    my ($ids, $cat) = @_;

    my @child_cats = $cat->children_categories;
    foreach (@child_cats) {
        unshift @$ids, $_->id;
        _get_descendant_category_ids($ids, $_);
    }
}

1;
