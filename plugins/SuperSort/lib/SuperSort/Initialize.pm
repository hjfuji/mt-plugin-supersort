#
# Initialize.pm
#
# 2008/10/20 1.00b1 Beta release
#
# Copyright(c) by H.Fujimoto
#
package SuperSort::Initialize;

use strict;

use MT;
use MT::Plugin;
use MT::Blog;
use MT::Entry;
use MT::Page;
use MT::Category;
use MT::Folder;
use SuperSort::Util qw ( left_join_placement );

use MT::Util qw( encode_js );

use JSON;
#use Data::Dumper;

use constant PER_INIT => 100;

my (%cat_info, @cat_labels);

# start initialize
sub init_start {
    my $app = shift;
    my $plugin = MT->component('SuperSort');
    my %param;

    # initialize
    my $blog_id = $app->param('blog_id');
    if (!$blog_id) {
        $app->redirect($app->uri(mode => 'dashboard', args => { blog_id => 0 }));
    }
    my $blog = $app->blog;
    my $type = $app->param('type');
    my $cat_class_name = ($type eq 'folder') ? 'folder' : 'category';
    my $cat_plural = ($type eq 'folder') ? 'folders' : 'categories';
    my $entry_class_name = ($type eq 'folder') ? 'page' : 'entry';
    my $entry_plural = ($type eq 'folder') ? 'pages' : 'entries';
    $param{cat_plural} = $plugin->translate($cat_plural);
    $param{cat_single} = $plugin->translate($cat_class_name);
    $param{entry_plural} = $plugin->translate($entry_plural);
    $param{entry_single} = $plugin->translate($entry_class_name);
    $param{type} = $cat_class_name;

    # load categories
    my @cats;
    my $cat_class = MT->model($cat_class_name);
    _init_start_load_categories_recursive($cat_class, $blog_id, \@cats, 0, 0);
    $param{cats_data} = \@cats;

    # build page
    $param{blog_id} = $app->param('blog_id');
    $param{can_category} = 1 if (MT->version_number >= 6 || $blog->is_blog);
    $param{position_actions_bottom} = 1;
    my $tmpl = $plugin->load_tmpl('init_setting.tmpl');
    $tmpl->text($plugin->translate_templatized($tmpl->text));
    $app->build_page($tmpl, \%param);
}

sub _init_start_load_categories_recursive {
    my ($cat_class, $blog_id, $cats, $parent, $depth) = @_;

    my @cats = $cat_class->load({ blog_id => $blog_id,
                                  parent => $parent });
    for my $cat (@cats) {
        push @$cats, { cat_id => $cat->id,
                       cat_label => "&nbsp;" x ($depth * 2) . $cat->label };
        &_init_start_load_categories_recursive($cat_class, $blog_id, $cats, $cat->id, $depth + 1);
    }
}

# initialize main
sub init_main {
    my $app = shift;
    my $plugin = MT->component('SuperSort');
    my %param;

    # initialize
    my $blog_id = $app->param('blog_id');
    my $type = $app->param('type');
    my $cat_class_name = ($type eq 'folder') ? 'folder' : 'category';
    my $cat_plural = ($type eq 'folder') ? 'folders' : 'categories';
    my $entry_class_name = ($type eq 'folder') ? 'page' : 'entry';
    my $entry_plural = ($type eq 'folder') ? 'pages' : 'entries';
    $param{cat_plural} = $plugin->translate($cat_plural);
    $param{cat_single} = $plugin->translate($cat_class_name);
    $param{entry_plural} = $plugin->translate($entry_plural);
    $param{entry_single} = $plugin->translate($entry_class_name);
    $param{sort_cat} = $app->param('sort_cat');
    $param{sort_entry} = $app->param('sort_entry');
    $param{type} = $app->param('type');
    $param{per_init} = PER_INIT;

    # load base category
    my $base_cat_id = $app->param('base_cat');
    my $cat_class = MT->model($cat_class_name);
    my ($base_cat, $base_cat_label);
    if ($base_cat_id) {
        $base_cat = $cat_class->load($base_cat_id);
        $base_cat_label = $base_cat->label;
    }
    else {
        $base_cat_label = $plugin->translate("Root " . $cat_class_name);
    }

    # load categories
    my @cats;
    push @cats, { cat_id => $base_cat_id, cat_label => $base_cat_label };
    if ($app->param('recursive')) {
        _init_main_load_categories_recursive($cat_class, $blog_id, \@cats, $base_cat_id);
    }
    $param{cats_data} = \@cats;

    # build page
    $param{blog_id} = $app->param('blog_id');
    $param{position_actions_bottom} = 1;
    my $tmpl = $plugin->load_tmpl('init.tmpl');
    $tmpl->text($plugin->translate_templatized($tmpl->text));
    $app->build_page($tmpl, \%param);
}

sub _init_main_load_categories_recursive {
    my ($cat_class, $blog_id, $cats, $parent) = @_;

    my @cats = $cat_class->load({ blog_id => $blog_id,
                                  parent => $parent });
    for my $cat (@cats) {
        push @$cats, { cat_id => $cat->id,
                       cat_label => $cat->label };
        &_init_main_load_categories_recursive($cat_class, $blog_id, $cats, $cat->id);
    }
}

# initialize category order
sub init_cat_order {
    my $app = shift;
    my $plugin = MT->component('SuperSort');
    my %param;

    # initialize
    my $blog_id = $app->param('blog_id');
    my $class_name = $app->param('type');
    my $class = MT->model($class_name);
    my $entry_class_name = $class_name eq 'category' ? 'entry' : 'page';
    my $entry_class = MT->model($entry_class_name);
    my $sort = $app->param('sort');
    my $parent = $app->param('parent');

    # load categories
    my (%terms, %args);
    $terms{blog_id} = $blog_id;
    $terms{parent} = $parent;
    if ($sort eq 'label_asc' || $sort eq 'mt51') {
        $args{sort} = 'label';
        $args{direction} = 'ascend';
    }
    elsif ($sort eq 'label_desc') {
        $args{sort} = 'label';
        $args{direction} = 'descend';
    }
    elsif ($sort eq 'current') {
        $args{sort} = 'order_number';
        $args{direction} = 'ascend';
    }

    my $entry_count;
    eval {
        # save category order
        if ($sort ne 'none') {
            my @cats = $class->load(\%terms, \%args);
            if ($sort eq 'mt51') {
                my $blog = $app->blog;
                my @sort_order = split ',', $blog->meta($class_name . '_order');
                my %sort_order;
                my $i = 0;
                foreach (@sort_order) {
                    $sort_order{$_} = $i;
                    $i++;
                }
                @cats = sort { $sort_order{$a->id} <=> $sort_order{$b->id} } @cats;
            }
            my $i = 1;
            for my $cat (@cats) {
                $cat->order_number($i);
                $cat->save or die;
                $i++;
            }
        }

        # count entries in parent category
        if ($parent == 0) {
            $entry_count = $entry_class->count(
                               {
                                   blog_id => $blog_id,
                               },
                               {
                                   join => left_join_placement(),
                               },
                           );
        }
        else {
            $entry_count = $entry_class->count(
                               {
                                   blog_id => $blog_id
                               },
                               {
                                   join => MT->model('placement')->join_on(
                                       'entry_id',
                                       { category_id => $parent }
                                   ),
                               }
                           );
        }
    };
    $app->send_http_header("text/plain");
    $app->{no_print_body} = 1;
    if ($@) {
        $app->print('-1');
    }
    else {
        $app->print($entry_count);
    }
}

# initialize entry order
sub init_entry_order {
    my $app = shift;
    my $plugin = MT->component('SuperSort');
    my %param;

    my $blog_id = $app->param('blog_id');
    my $class_name = $app->param('type');
    my $entry_class_name = $class_name eq 'category' ? 'entry' : 'page';
    my $class = MT->model($entry_class_name);
    my $cat_id = $app->param('parent');
    my $offset = $app->param('offset');
    my $sort = $app->param('sort');

#    $plugin->do_log('class_name = ' . $class_name . 'entry_class_name = ' . $entry_class_name . ', class = ' . $class . ', cat_id = ' . $cat_id . ', entry_offset = ' . $offset);

    my (%terms, %args);
    $terms{blog_id} = $blog_id;
    if ($sort eq 'date_asc') {
        $args{sort} = 'authored_on';
        $args{direction} = 'ascend';
    }
    elsif ($sort eq 'date_desc') {
        $args{sort} = 'authored_on';
        $args{direction} = 'descend';
    }
    elsif ($sort eq 'title_asc') {
        $args{sort} = 'title';
        $args{direction} = 'ascend';
    }
    elsif ($sort eq 'title_desc') {
        $args{sort} = 'title';
        $args{direction} = 'descend';
    }

    $args{offset} = $offset;
    $args{limit} = PER_INIT;
    if ($cat_id == 0) {
        $args{join} = left_join_placement();
        if ($sort eq 'current') {
            $args{sort} = 'order_number';
            $args{direction} = 'ascend';
        }
        my @entries = $class->load(\%terms, \%args);
        my $i = $offset + 1;
        for my $entry (@entries) {
            $entry->order_number($i);
            $entry->save;
            $i++;
        }
    }
    else {
        my $join_args = {};
        if ($sort eq 'current') {
            $join_args->{sort} = 'order_number';
            $join_args->{direction} = 'ascend';
            delete $args{sort};
            delete $args{direction};
        }
        $args{join} = MT->model('placement')->join_on(
            'entry_id',
            { category_id => $cat_id },
            $join_args,
        );
        my @entries = $class->load(\%terms, \%args);
        my $i = $offset + 1;
        for my $entry (@entries) {
            my $place = MT::Placement->load({ entry_id => $entry->id,
                                              category_id => $cat_id });
            $place->order_number($i);
            $place->save;
            $i++;
        }
    }
    $app->send_http_header("text/plain");
    $app->{no_print_body} = 1;
    $app->print('ok');
}

sub _init_start_recursive {
    my ($cat_class_name, $cat_class, $entry_class_name, $entry_class, $column, $blog_id, $parent) = @_;

    my (%terms, %args);
    $terms{blog_id} = $blog_id;
    $terms{parent} = $parent;
    $args{sort} = $column;
    $args{direction} = 'ascend';
    my @objs = $cat_class->load(\%terms, \%args);

    my $i = 0;
    for my $obj (@objs) {
        # set category / folder order number
        $obj->order_number($i + 1);
        $obj->save
            or return { code => 0, msg => $obj->errstr };
        # count entry of category / folder
        my @args = ({ blog_id => $blog_id },
                    { 'join' => [ 'MT::Placement', 'entry_id',
                                  { category_id => $obj->id } ] });
        my $count = scalar $entry_class->count(@args);
        # set category / folder information
        push @cat_labels, $obj->label;
#        push @cat_labels, MT::I18N::encode_text($obj->label, 'utf-8', $charset);
        if ($count) {
            push @{$cat_info{$cat_class_name}},
                { id => $obj->id,
                  label => encode_js(join('::', @cat_labels)),
                  count => $count };
        }
        my $result = _init_start_recursive($cat_class_name, $cat_class, $entry_class_name, $entry_class, $column, $blog_id, $obj->id);
        pop @cat_labels;
        if (!$result->{code}) {
            return $result;
        }
        $i++;
    }
    return { code => 1, msg => ''};
}

# save mt5 native category / folder sort order
sub init_save_mt5_order {
    my $app = shift;
    my $plugin = MT->component('SuperSort');

    my $blog_id = $app->param('blog_id');
    my $class_name = $app->param('type');
    my $class = MT->model($class_name);
    $app->send_http_header("text/plain");
    $app->{no_print_body} = 1;
    eval {
        my @cats = $class->load({ blog_id => $blog_id });
        my $ser_cats = [];
        _serialize_cats($ser_cats, \@cats, 0);
        my $blog = $app->blog;
        $blog->meta($class_name . '_order', join(',', @$ser_cats));
        $blog->save;
    };
    $app->print($@ ? 'ng' : 'ok');
}

sub _serialize_cats {
    my ($ser_cats, $cats, $parent) = @_;

    my @sib_cats = grep { $_->parent == $parent } @$cats;
    @$cats = grep { $_->parent != $parent } @$cats;
    @sib_cats = sort { $a->order_number <=> $b->order_number } @sib_cats;
    foreach (@sib_cats) {
        push @$ser_cats, $_->id;
        _serialize_cats($ser_cats, $cats, $_->id);
    }
}

sub move_start {
    my $app = shift;
    my $plugin = MT->component('SuperSort');
    my %param;

    if ($app->param('id')) {
        my @blog_ids = $app->param('id');
        $param{blog_ids} = join ',', @blog_ids;
        $param{count} = scalar @blog_ids;
    }
    else {
        # load all websites and blogs
        my @blogs = MT->model('blog')->load({ class => [ 'blog', 'website' ] });
        $param{blog_ids} = join ',', (map { $_->id } @blogs);
        $param{count} = scalar @blogs;
    }
    $param{offset} = 0;
    my $tmpl = $plugin->load_tmpl('move_start.tmpl');
    $tmpl->text($plugin->translate_templatized($tmpl->text));
    return $app->build_page($tmpl, \%param);
}

sub select_blogs {
    my $app = shift;
    my $plugin = MT->component('SuperSort');
    my %param;

    # check permission
    my $user = $app->user
        or return $app->error($plugin->translate('Load user error'));
    return $app->error($plugin->translate('You are not an administrator.'))
        unless ($user->is_superuser);

    # set data
    my @data;
    my $odd = 0;
    my @websites = MT->model('website')->load;
    for my $website (@websites) {
        push @data, {
            id => $website->id,
            name => $website->name ? $website->name : $plugin->translate('No name'),
            description => $website->description,
            odd => $odd,
            is_blog => 0,
        };
        $odd = !$odd;
        my @blogs = MT->model('blog')->load(
                        {
                            parent_id => $website->id
                        },
                        {
                            sort => 'name',
                            direction => 'ascend',
                        }
                    );
        for my $blog (@blogs) {
            push @data, {
                id => $blog->id,
                name => $blog->name ? $blog->name : $plugin->translate('No name'),
                description => $blog->description,
                odd => $odd,
                is_blog => 1,
            };
            $odd = !$odd;
        }
    }
    $param{position_actions_top} = 1;
    $param{limit_none} = 1;
    $param{empty_message} = $plugin->translate('No websites / blogs found.');
    $param{listing_screen} = 1;
    $param{object_loop}         = \@data;
    $param{object_label}        = $plugin->translate('Website / Blog');
    $param{object_label_plural} = $plugin->translate('Websites / Blogs');
    $param{object_type}         = 'blog';

    # show page
    my $tmpl = $plugin->load_tmpl('select_blogs.tmpl');
    $tmpl->text($plugin->translate_templatized($tmpl->text));
    $app->build_page($tmpl, \%param);
}

sub move {
    my $app = shift;
    my $plugin = MT->component('SuperSort');
    my %param;

    my $blog;
    eval {
        my $blog_id = $app->param('blog_id');
        $blog = MT->model('blog')->load($blog_id) ||
                MT->model('website')->load($blog_id);
        my @classes = ($blog->is_blog)
                    ? qw( category folder ) : qw( folder );
        for my $class (@classes) {
            my $ser_cats = [];
            _recursive_load_cats($ser_cats, $class, $blog_id, 0);
            $blog->meta($class . '_order', join ',', (map { $_->id } @$ser_cats));
        }
        $blog->save;
    };
    my $json = '{"blog_name":"' . encode_js($blog->name) . '",';
    $json .= '"is_blog":' . ($blog->is_blog ? '1' : '0') . ",";
    if ($@) {
        $json .= '"error":"' . encode_js($@) . '"}';
    }
    else {
        $json .= '"ok":1}'
    }

    $app->send_http_header("application/json");
    $app->{no_print_body} = 1;
    $app->print_encode($json);
    return undef;
}

sub _recursive_load_cats {
    my ($ser_cats, $class, $blog_id, $parent) = @_;

    my @cats = MT->model($class)->load(
                   { blog_id => $blog_id, parent => $parent },
                   { sort => 'label', direction => 'ascend' }
               );
    my $order_number = scalar @cats + 1;
    @cats = map {
        unless ($_->order_number) {
            $_->order_number($order_number);
            $order_number++;
        }
        $_;
    } @cats;
    @cats = sort { $a->order_number <=> $b->order_number} @cats;
    foreach (@cats) {
        push @$ser_cats, $_;
        _recursive_load_cats($ser_cats, $class, $blog_id, $_->id);
    }
}

# remove orphan categories
sub remove_orphan_categories {
    my $class = MT->model('category');
    my @parent_ids = $class->load(
                         {
                             class => '*',
                             parent => { not => 0 },
                         },
                         {
                             fetchonly => { parent => 1 },
                         }
                     );
    my %parent_ids;
    foreach (@parent_ids) {
        $parent_ids{$_->parent} = 1;
    }
    my @parent_cats = $class->load({ id => [ keys %parent_ids ] });
    my %exist_ids;
    foreach (@parent_cats) {
        $exist_ids{$_->id} = 1;
    }
    my @zombie_ids = grep { !exists($exist_ids{$_}) } keys %parent_ids;
    for (@zombie_ids) {
        _remove_orphans($_);
    }
}

sub _remove_orphans {
    my $cat_id = shift;
    my $class = MT->model('category');
    my @cats = $class->load({
                   class => '*',
                   parent => $cat_id
               });
    foreach (@cats) {
        _remove_orphans($_->id);
        $_->remove;
    }
}

1;
