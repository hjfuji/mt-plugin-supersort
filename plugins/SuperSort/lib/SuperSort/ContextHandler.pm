#
# ContextHandler.pm
#
# 2008/10/20 1.00b1 Beta release
# 2009/03/10 1.00rc2 Release Candidate 2
#
# Copyright(c) by H.Fujimoto
#
package SuperSort::ContextHandler;

use strict;

use MT;
use MT::Plugin;
use MT::Blog;
use MT::Entry;
use MT::Page;
use MT::Category;
use MT::Folder;
use MT::Placement;
use MT::Request;
use MT::Template::Context;
use SuperSort::Util qw ( load_adjacent_entry left_join_placement );

# MTSortedEntries tag
sub sorted_entries {
    my ($ctx, $args, $cond) = @_;
    my $plugin = MT->component('SuperSort');

    # initialize
    my $class_type = $args->{class_type} || 'entry';
    my $class = MT->model($class_type);
    my $cat_class = MT->model($class_type eq 'entry' ? 'category' : 'folder');
    my $blog = $ctx->stash('blog');

    # load entries
    my $cat;
    if ($args->{category}) {
        $cat = $cat_class->load({ blog_id => $blog->id,
                                  label => $args->{category} });
        if (!$cat) {
            return $ctx->error(
                $plugin->translate(
                    "[_1] '[_2]' doesn't exist.",
                    $plugin->translate($class_type eq 'entry'
                                       ? 'Category' : 'Folder'),
                    $args->{category}
                )
            );
        }
    }
    elsif ($args->{category_id}) {
        $cat = $cat_class->load($args->{category_id});
        if (!$cat) {
            return $ctx->error(
                $plugin->translate(
                    "[_1] whose id is [_2] doesn't exist.",
                    $plugin->translate($class_type eq 'entry'
                                       ? 'Category' : 'Folder'),
                    $args->{category_id}
                )
            );
        }
    }
    else {
        $cat = $ctx->stash('category') || $ctx->stash('archive_category');
    }
    my (@entries, %terms, %args);
    $terms{blog_id} = $blog->id;
    $terms{status} = MT::Entry::RELEASE();
    my $sort_order = $args->{sort_order} || 'ascend';
    if ($args->{offset} || $args->{lastn}) {
        $args{offset} = $args->{offset} if ($args->{offset});
        $args{limit} = $args->{lastn} if ($args->{lastn} && $args->{lastn} ne 'all');
    }
    else {
        $args{limit} = $blog->entries_on_index;
    }

    if (!$cat || $args->{root}) {
        $args{join} = left_join_placement();
        $args{sort} = 'order_number';
        $args{direction} = $sort_order;
    }
    else {
        $args{join} = MT->model('placement')->join_on(
                          'entry_id',
                          { category_id => $cat->id },
                          { sort => 'order_number',
                            direction => $sort_order }
                      );
    }
    @entries = $class->load(\%terms, \%args);

    # out entries
    my $tok = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    my($last_day, $next_day) = ('00000000') x 2;
    my $res = '';
    my $i = 0;
    my $glue = $args->{glue};
    my $vars = $ctx->{__stash}{vars} ||= {};
    local $vars->{__size__} = scalar(@entries);
    local $ctx->{__stash}{category} = $cat if ($cat);
    if (scalar @entries) {
        for my $e (@entries) {
            local $vars->{__first__} = !$i;
            local $vars->{__last__} = !defined $entries[$i + 1];
            local $vars->{__odd__} = ($i % 2) == 0;
            local $vars->{__even__} = ($i % 2) == 1;
            local $vars->{__counter__} = $i + 1;
            local $ctx->{__stash}{blog} = $e->blog;
            local $ctx->{__stash}{blog_id} = $e->blog_id;
            local $ctx->{__stash}{entry} = $e;
            local $ctx->{current_timestamp} = $e->authored_on;
            local $ctx->{modification_timestamp} = $e->modified_on;
            my $this_day = substr $e->authored_on, 0, 8;
            my $next_day = $this_day;
            my $footer = 0;
            if (defined $entries[$i+1]) {
                $next_day = substr($entries[$i + 1]->authored_on, 0, 8);
                $footer = $this_day ne $next_day;
            }
            else {
                $footer++;
            }
            my $allow_comments ||= 0;
            my $out = $builder->build($ctx, $tok, {
                %$cond,
                DateHeader => ($this_day ne $last_day),
                DateFooter => $footer,
                EntriesHeader => $class_type eq 'entry' ?
                    (!$i) : (),
                EntriesFooter => $class_type eq 'entry' ?
                    (!defined $entries[$i + 1]) : (),
                PagesHeader => $class_type ne 'entry' ?
                    (!$i) : (),
                PagesFooter => $class_type ne 'entry' ?
                    (!defined $entries[$i + 1]) : (),
            });
            return $ctx->error($builder->errstr) unless defined $out;
            $last_day = $this_day;
            $res .= $glue if defined $glue && $i && length($res) && length($out);
            $res .= $out;
            $i++;
        }
    }
    else {
        $res = $ctx->else($args, $cond);
    }
    $res;
}

# MTSortedEntries tag
sub sorted_pages {
    my ($ctx, $args, $cond) = @_;
    my $plugin = MT->component('SuperSort');

    $args->{class_type} = 'page';
    if ($args->{folder}) {
        $args->{category} = $args->{folder};
        delete $args->{folder};
    }
    if ($args->{folder_id}) {
        $args->{category_id} = $args->{folder_id};
        delete $args->{folder_id};
    }
    &sorted_entries($ctx, $args, $cond);
}

# MTSortedEntryPrevious tag
# MTSortedEntryNext tag
sub sorted_entry_prev_next {
    my ($ctx, $args, $cond) = @_;
    my $plugin = MT->component('SuperSort');

    # initialize
    my $class_type = $args->{class_type} || 'entry';
    my $class = MT->model($class_type);
    my $blog = $ctx->stash('blog');
    my $tag = lc $ctx->stash('tag');
    my $entry = $ctx->stash('entry')
        or return $ctx->_no_entry_error();
    my $mode = ($tag =~ /sorted(entry|page)previous/) ? 'prev' : 'next';

    # load adjacent entry
    my $cat;
    my $at = $ctx->{current_archive_type} || $ctx->{archive_type};
    $at = lc $at;
    if (($at eq 'individual' || $at eq 'page') &&
        !$ctx->{inside_mt_categories}) {
        $cat = $entry->category;
    }
    else {
        $cat = $ctx->stash('category') || $ctx->stash('archive_category');
        my @places = MT::Placement->load({ entry_id => $entry->id });
        if (!$cat && scalar(@places)) {
            return $ctx->error(MT->translate(
                "You used an [_1] tag outside of the proper context.",
                '<$MT'.$ctx->stash('tag').'$>'));
        }
    }
    my $adj_entry = load_adjacent_entry($class_type, $mode, $entry, $blog, $cat);

    # output
    my $res = '';
    if ($adj_entry) {
        # out entry
        my $tok = $ctx->stash('tokens');
        my $builder = $ctx->stash('builder');
        local $ctx->{__stash}->{entry} = $adj_entry;
        local $ctx->{current_timestamp} = $adj_entry->authored_on;
        my $out = $builder->build($ctx, $tok, $cond);
        return $ctx->error($builder->errstr) unless defined $out;
        $res .= $out;
    }
    return $res;
}

# MTSortedCategoryPrevious tag
# MTSortedCategoryNext tag
sub sorted_category_prev_next {
    my ($ctx, $args, $cond) = @_;
    my $plugin = MT->component('SuperSort');

    my $res = '';
    my $cat = $ctx->stash('category') || $ctx->stash('archive_category');
    if ($cat) {
        # initialize
        my $tag = lc $ctx->stash('tag');
        my $direction = ($tag =~ /sorted(category|folder)previous/)
                        ? 'descend' : 'ascend';
        my $class = MT->model($cat->class);
        my $order_number = $cat->order_number;
        my $adj_cat;
        my $now_cat = $cat;
        while () {
            # load adjacent category
            my $range = ($direction eq 'descend')
                        ? [ 0, $order_number ]
                        : [ $order_number, undef ];
            $adj_cat = $class->load({ blog_id => $cat->blog_id,
                                      parent => $cat->parent,
                                      order_number => $range },
                                    { sort => 'order_number',
                                      direction => $direction,
                                      range => { order_number => 1 },
                                      limit => 1 });

            # last if no adjacent category
            last if (!$adj_cat);
            # last if no_skip argument
            last if ($args->{no_skip});
            # last if entry count of category is not zero
            my @args = ({ blog_id => $ctx->stash('blog_id'),
                          status => MT::Entry::RELEASE() },
                        { 'join' => [ 'MT::Placement', 'entry_id',
                                      { category_id => $adj_cat->id } ] });
            my $entry_class = MT->model(($cat->class eq 'category') ? 'entry' : 'page');
            my $count = scalar $entry_class->count(@args);
            last if ($count);
            # search next adjacent category
            $order_number = $adj_cat->order_number;
            $now_cat = $adj_cat;
        }
        if ($adj_cat) {
            # out category
            my $tok = $ctx->stash('tokens');
            my $builder = $ctx->stash('builder');
            local $ctx->{__stash}->{category} = $adj_cat;
            my $out = $builder->build($ctx, $tok, $cond);
            return $ctx->error($builder->errstr) unless defined $out;
            $res .= $out;
        }
    }
    return $res;
}

# MTSortedFolderPrevious tag
# MTSortedFolderNext tag
sub sorted_folder_prev_next {
    my ($ctx, $args, $cond) = @_;
    my $plugin = MT->component('SuperSort');

    return undef unless MT::Template::Tags::Folder::_check_folder($ctx, $args, $cond);
    &sorted_category_prev_next(@_);
}

# MTSortedEntryPrevious tag
# MTSortedEntryNext tag
sub sorted_page_prev_next {
    my ($ctx, $args, $cond) = @_;
    my $plugin = MT->component('SuperSort');

    $args->{class_type} = 'page';
    &sorted_entry_prev_next($ctx, $args, $cond);
}

# MTEntryOrderNumber tag
sub entry_order_number {
    my ($ctx, $args) = @_;
    my $plugin = MT->component('SuperSort');

    my $entry = $ctx->stash('entry')
        or return $ctx->_no_entry_error();
    my @places = MT::Placement->load({ entry_id => $entry->id });
    if (scalar @places) {
        my $cat;
        my $at = $ctx->{current_archive_type} || $ctx->{archive_type};
        $at = lc $at;
        if (($at eq 'individual' || $at eq 'page') &&
            !$ctx->{inside_mt_categories}) {
            $cat = $entry->category;
        }
        else {
            $cat = $ctx->stash('category') || $ctx->stash('archive_category');
            if (!$cat && scalar(@places)) {
                return $ctx->error(MT->translate(
                    "You used an [_1] tag outside of the proper context.",
                    '<$MT'.$ctx->stash('tag').'$>'));
            }
        }
        map { return $_->order_number if ($_->category_id == $cat->id) } @places;        return '0';
    }
    else {
        return $entry->order_number;
    }
}

# MTCategoryOrderNumber tag
sub category_order_number {
    my ($ctx, $args) = @_;
    my $plugin = MT->component('SuperSort');

    my $cat = ($ctx->stash('category') || $ctx->stash('archive_category'))
        or return $ctx->error(MT->translate(
            "You used an [_1] tag outside of the proper context.",
            '<$MT'.$ctx->stash('tag').'$>'));
    $cat->order_number;
}

# MTFolderOrderNumber tag
sub folder_order_number {
    my ($ctx, $args, $cond) = @_;
    my $plugin = MT->component('SuperSort');

    return undef unless MT::Template::Tags::Folder::_check_folder($ctx, $args, $cond);
    &category_order_number(@_);
}

# MTSortedEntryCategories tag
sub sorted_entry_categories {
    my ($ctx, $args, $cond) = @_;
    my $plugin = MT->component('SuperSort');

    my $entry = $ctx->stash('entry')
        or return $ctx->_no_entry_error();
    my $cats = $entry->categories;
    return '' if (!$cats);

    # load sorted categories
    my $req = MT::Request->instance;
    my $sorted_cats = $req->stash('SuperSort::SortedCats');
    unless(defined($sorted_cats)) {
        $sorted_cats = {};
        my $order = 1;
        my $blog_id = $ctx->stash('blog_id');
        &_load_sorted_categories($sorted_cats, $blog_id, 0, \$order);
        $req->stash('SuperSort::SortedCats', $sorted_cats);
    }
    # sort and grep categories
    my $pri_cat = $entry->category;
    if ($args->{exclude_primary} || $args->{primary_first} || $args->{primary_last}) {
        @$cats = grep { $_->id != $pri_cat->id } @$cats;
    }
    @$cats = sort { $sorted_cats->{$a->id}->{order} <=>
                    $sorted_cats->{$b->id}->{order} } @$cats;
    if ($args->{primary_first} && !$args->{exclude_primary} && $pri_cat) {
        unshift @$cats, $pri_cat;
    }
    elsif ($args->{primary_last} && !$args->{exclude_primary} && $pri_cat) {
        push @$cats, $pri_cat;
    }

    # out
    my $tokens = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    my @res = ();
    my $entry_class = MT->model('entry');
    my $glue = $args->{glue} || '';
    my $vars = $ctx->{__stash}{vars} ||= {};
    local $vars->{__size__} = scalar(@$cats);
    my $i = 0;

    for my $cat (@$cats) {
        local $ctx->{inside_mt_categories} = 1;
        local $ctx->{__stash}->{category} = $cat;
        local $vars->{__primary__} = ($cat->id == $pri_cat->id);
        local $vars->{__order__} = $sorted_cats->{$cat->id}->{order};
        local $vars->{__first__} = !$i;
        local $vars->{__last__} = !defined $cats->[$i + 1];
        local $vars->{__odd__} = ($i % 2) == 0;
        local $vars->{__even__} = ($i % 2) == 1;
        local $vars->{__counter__} = $i + 1;
        defined(my $out = $builder->build($ctx, $tokens, $cond))
            or return $ctx->error($builder->errstr);
        push @res, $out;
        $i++;
    }
    join $glue, @res;
}

sub _load_sorted_categories {
    my ($sorted_cats, $blog_id, $parent, $order) = @_;

    my $class = MT->model('category');
    my @cats = $class->load({ blog_id => $blog_id,
                              parent => $parent },
                            { sort => 'order_number',
                              direction => 'ascend' });
    for my $cat (@cats) {
        $sorted_cats->{$cat->id} = { label => $cat->label, order => $$order };
        $$order++;
        &_load_sorted_categories($sorted_cats, $blog_id, $cat->id, $order);
    }
}

# MTSortedTopLevelCategories tag
sub sorted_top_level_categories {
    my ($ctx, $args, $cond) = @_;
    my $plugin = MT->component('SuperSort');

    return $ctx->invoke_handler('toplevelcategories', $args, $cond);
}

# MTSortedSubCategories tag
sub sorted_sub_categories {
    my ($ctx, $args, $cond) = @_;
    my $plugin = MT->component('SuperSort');

    return $ctx->invoke_handler('subcategories', $args, $cond);
}

# MTSortedTopLevelFolders tag
sub sorted_top_level_folders {
    my ($ctx, $args, $cond) = @_;
    my $plugin = MT->component('SuperSort');

    return $ctx->invoke_handler('toplevelfolders' , $args, $cond);
}

# MTSortedSubFolders tag
sub sorted_sub_folders {
    my ($ctx, $args, $cond) = @_;
    my $plugin = MT->component('SuperSort');

    return $ctx->invoke_handler('subfolders', $args, $cond);
}

1;
