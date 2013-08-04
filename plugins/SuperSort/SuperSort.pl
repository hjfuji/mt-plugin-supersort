#
# SuperSort.pl
# 2008/10/20 1.00b1 Beta release
# 2009/02/02 1.00rc1 Release Candidate 1
# 2009/03/10 1.00rc2 Release Candidate 2
# 2009/03/26 1.00
# 2009/11/18 1.10b1 Beta release for Movable Type 5
# 2010/02/15 1.10RC1 RC1 for Movable Type 5
# 2010/05/15 1.10RC2 RC2 for Movable Type 5.02
# 2010/06/01 1.10
# 2011/05/26 1.20b1 Beta release for Movable Type 5.1
# 2012/07-20 1.20b2 For Movable Type 5.2
#
# Copyright(c) by H.Fujimoto
#
package MT::Plugin::SuperSort;
use base 'MT::Plugin';

use strict;

use MT::Plugin;
use MT;
use MT::Category;
use MT::Folder;
use MT::Entry;
use MT::Page;
use MT::Template::Context;

# show plugin information to main menu
my $plugin = __PACKAGE__->new({
    name => 'SuperSort',
    id => 'super_sort',
    key => 'super_sort',
    version => '1.20b3',
    author_name => '<__trans phrase="Hajime Fujimoto">',
    author_link => 'http://www.h-fj.com/blog/',
    doc_link => 'http://www.h-fj.com/blog/mtplgdoc/supersort.php',
    description => '<__trans phrase="This plugin enables you to sort entries, pages, categories and folders.">',
    blog_config_template => \&blog_config,
    system_config_template => 'system_config.tmpl',
    settings => new MT::PluginSettings([
        ['fjss_enabled_sort_entry', { Default => 0 }],
        ['fjss_enabled_sort_page', { Default => 0 }],
        ['fjss_auto_rebuild_entry', { Default => 1 }],
        ['fjss_auto_rebuild_page', { Default => 1 }],
        ['fjss_auto_rebuild_after_delete_entry', { Default => 1 }],
        ['fjss_auto_rebuild_after_delete_page', { Default => 1 }],
        ['fjss_enabled_drag_and_drop', { Default => 1 }],
    ]),
    schema_version => '1.01',
    l10n_class => 'SuperSort::L10N',
});
MT->add_plugin($plugin);

# do_log
sub do_log {
    my ($plugin, $msg) = @_;

    require MT::Log;
    my $log = MT::Log->new;
    $log->message($msg);
    $log->save;
}

# add tag
sub init_registry {
    my $plugin = shift;
    my $reg = {
        tags => {
            block => {
                'SortedEntries' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'sorted_entries', @_); },
                'SortedPages' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'sorted_pages', @_); },
                'SortedEntryPrevious' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'sorted_entry_prev_next', @_); },
                'SortedEntryNext' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'sorted_entry_prev_next', @_); },
                'SortedPagePrevious' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'sorted_page_prev_next', @_); },
                'SortedPageNext' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'sorted_page_prev_next', @_); },
                'SortedCategoryPrevious' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'sorted_category_prev_next', @_); },
                'SortedCategoryNext' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'sorted_category_prev_next', @_); },
                'SortedFolderPrevious' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'sorted_folder_prev_next', @_); },
                'SortedFolderNext' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'sorted_folder_prev_next', @_); },
                'SortedEntryCategories' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'sorted_entry_categories', @_); },
                'SortedTopLevelCategories' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'sorted_top_level_categories', @_); },
                'SortedSubCategories' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'sorted_sub_categories', @_); },
                'SortedTopLevelFolders' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'sorted_top_level_folders', @_); },
                'SortedSubFolders' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'sorted_sub_folders', @_); },
            },
            function => {
                'EntryOrderNumber' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'entry_order_number', @_); },
                'PageOrderNumber' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'entry_order_number', @_); },
                'CategoryOrderNumber' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'category_order_number', @_); },
                'FolderOrderNumber' =>
                    sub { runner('SuperSort::ContextHandler',
                                 'folder_order_number', @_); },
            },
        },
        object_types => {
            'entry' => {
                'order_number' => 'integer',
            },
            'placement' => {
                'order_number' => 'integer',
            },
            'category' => {
                'order_number' => 'integer',
            },
        },
        callbacks => {
            'MT::App::CMS::template_param.edit_category'
                => sub { runner('SuperSort::Transformer',
                                'edit_category', @_); },
            'MT::App::CMS::template_param.edit_folder'
                => sub { runner('SuperSort::Transformer',
                                'edit_category', @_); },
            'MT::App::CMS::template_param.edit_entry'
                => sub { runner('SuperSort::Transformer',
                                'edit_entry', @_); },
            'cms_pre_save.category' => {
                priority => 1,
                code => sub { runner('SuperSort::Callback',
                                     'pre_save_category', 'category', @_); },
            },
            'cms_pre_save.folder' => {
                priority => 1,
                code => sub { runner('SuperSort::Callback',
                                     'pre_save_category', 'folder', @_); },
            },
            'cms_post_save.category' => {
                priority => 1,
                code => sub { runner('SuperSort::Callback',
                                     'post_save_category', 'category', @_); },
            },
            'cms_post_save.folder' => {
                priority => 1,
                code => sub { runner('SuperSort::Callback',
                                     'post_save_category', 'folder', @_); },
            },
            'cms_post_delete.category' => {
                priority => 1,
                code => sub { runner('SuperSort::Callback',
                                     'post_delete_category', 'category', @_); },
            },
            'cms_post_delete.folder' => {
                priority => 1,
                code => sub { runner('SuperSort::Callback',
                                     'post_delete_category', 'folder', @_); },
            },
            'cms_pre_save.entry' => {
                priority => 1,
                code => sub { runner('SuperSort::Callback',
                                     'pre_save_entry', 'entry', @_); },
            },
            'cms_pre_save.page' => {
                priority => 1,
                code => sub { runner('SuperSort::Callback',
                                     'pre_save_entry', 'page', @_); },
            },
            'cms_post_save.entry' => {
                priority => 1,
                code => sub { runner('SuperSort::Callback',
                                     'post_save_entry', 'entry', @_); },
            },
            'cms_post_save.page' => {
                priority => 1,
                code => sub { runner('SuperSort::Callback',
                                     'post_save_entry', 'page', @_); },
            },
            'cms_post_delete.entry' => {
                priority => 1,
                code => sub { runner('SuperSort::Callback',
                                     'post_delete_entry', 'entry', @_); },
            },
            'cms_post_delete.page' => {
                priority => 1,
                code => sub { runner('SuperSort::Callback',
                                     'post_delete_entry', 'page', @_); },
            },
            'cms_delete_permission_filter.entry' => {
                priority => 1,
                code => sub { runner('SuperSort::Callback',
                                     'pre_delete_entry', @_); },
            },
            'cms_delete_permission_filter.page' => {
                priority => 1,
                code => sub { runner('SuperSort::Callback',
                                     'pre_delete_entry', @_); },
            },
            'cms_post_bulk_save.category' => {
                priority => 1,
                code => sub { runner('SuperSort::Callback',
                                     'bulk_save_categories', @_); },
            },
            'cms_post_bulk_save.folder' => {
                priority => 1,
                code => sub { runner('SuperSort::Callback',
                                     'bulk_save_categories', @_); },
            },
        },
        applications => {
            'cms' => {
                'menus' => {
                    'entry:fjss_cat_entry' => {
                        label      => 'Categories and entries',
                        mode       => 'fjss_sort_order',
                        order      => 350,
                        args       => { type => 'category' },
                        view       => (MT->version_number <= 6) ? [ 'blog', 'website' ] : 'blog',
                        permission => 'create_post,publish_post,edit_all_posts',
                        condition  => sub {
                            my $app = MT->instance;
                            my $blog_id = $app->param('blog_id') or return 0;
                            return $plugin->get_config_value('fjss_enabled_sort_entry', 'blog:' . $blog_id);
                        },
                    },
                    'page:fjss_fld_page' => {
                        label      => 'Folders and pages',
                        mode       => 'fjss_sort_order',
                        order      => 350,
                        args       => { type => 'folder' },
                        view       => [ 'blog', 'website' ],
                        permission => 'manage_pages',
                        condition  => sub {
                            my $app = MT->instance;
                            my $blog_id = $app->param('blog_id') or return 0;
                            return $plugin->get_config_value('fjss_enabled_sort_page', 'blog:' . $blog_id);
                        },
                    },
                },
                'methods' => {
                    'fjss_init_start' =>
                        sub { runner('SuperSort::Initialize',
                                     'init_start', @_); },
                    'fjss_init_main' =>
                        sub { runner('SuperSort::Initialize',
                                     'init_main', @_); },
                    'fjss_init_cat_order' =>
                        sub { runner('SuperSort::Initialize',
                                     'init_cat_order', @_); },
                    'fjss_init_entry_order' =>
                        sub { runner('SuperSort::Initialize',
                                     'init_entry_order', @_); },
                    'fjss_init_save_mt5_order' =>
                        sub { runner('SuperSort::Initialize',
                                     'init_save_mt5_order', @_); },
                    'fjss_sort_order' =>
                        sub { runner('SuperSort::Sort',
                                     'start_sort_order', @_); },
                    'fjss_load_categories' =>
                        sub { runner('SuperSort::Sort',
                                     'load_categories', @_); },
                    'fjss_load_entries' =>
                        sub { runner('SuperSort::Sort',
                                     'load_entries', @_); },
                    'fjss_save_start' =>
                        sub { runner('SuperSort::Sort',
                                     'save_start', @_); },
                    'fjss_save_moved_data' =>
                        sub { runner('SuperSort::Sort',
                                     'save_moved_data', @_); },
                    'fjss_save_cat_order' =>
                        sub { runner('SuperSort::Sort',
                                     'save_cat_order', @_); },
                    'fjss_save_entry_order' =>
                        sub { runner('SuperSort::Sort',
                                     'save_entry_order', @_); },
                    'fjss_select_category' =>
                        sub { runner('SuperSort::Sort',
                                     'select_category', @_); },
                    'fjss_get_child_categories' =>
                        sub { runner('SuperSort::Sort',
                                     'get_child_categories', @_); },
                    'fjss_move_start' =>
                        sub { runner('SuperSort::Initialize',
                                     'move_start', @_); },
                    'fjss_select_blogs' =>
                        sub { runner('SuperSort::Initialize',
                                     'select_blogs', @_); },
                    'fjss_move' => 
                        sub { runner('SuperSort::Initialize',
                                     'move', @_); },
                },
            },
        },
        upgrade_functions => {
            'remove_orphan_categories' => {
                version_limit => '1.01',
                code =>
                    sub { runner('SuperSort::Initialize',
                                 'remove_orphan_categories', @_); },
            },
        },
    };
    $plugin->registry($reg);
}

sub runner {
    my $class = shift;
    my $method = shift;

    eval "require $class;";
    if ($@) { die $@; $@ = undef; return 1; }
    my $method_ref = $class->can($method);
    return $method_ref->($plugin, @_) if $method_ref;
    die $plugin->translate("Failed to find [_1]::[_2]", $class, $method);
}

sub blog_config {
    my $app = MT->instance;
    my $script = $app->uri;
    my $blog = MT->instance->blog;
    my $blog_id = $blog->id;
    my ($links, $checkboxes);
    if (ref $blog eq 'MT::Blog' || MT->version_number >= 6) {
        $links = <<HERE;
    <__trans phrase="Please initialize sort order."><br />
    <a href="${script}?__mode=fjss_init_start&amp;blog_id=${blog_id}&amp;type=category"><__trans phrase="Initialize sort order of categories and entries"></a><br />
    <a href="${script}?__mode=fjss_init_start&amp;blog_id=${blog_id}&amp;type=folder"><__trans phrase="Initialize sort order of folders and pages"></a><br />
HERE
        $checkboxes = <<HERE;
    <input type="checkbox" name="fjss_enabled_sort_entry" id="fjss_enabled_sort_entry" value="1"<mt:if name="fjss_enabled_sort_entry" eq="1"> checked="checked"</mt:if> /> <__trans phrase="Enable to sort entries and categories"><br />
    <input type="checkbox" name="fjss_enabled_sort_page" id="fjss_enabled_sort_page" value="1"<mt:if name="fjss_enabled_sort_page" eq="1"> checked="checked"</mt:if> /> <__trans phrase="Enable to sort pages and folders">
HERE
    }
    else {
        $links = <<HERE;
    <__trans phrase="Please initialize sort order."><br />
    <a href="${script}?__mode=fjss_init_start&amp;blog_id=${blog_id}&amp;type=folder"><__trans phrase="Initialize sort order of folders and pages"></a><br />
HERE
        $checkboxes = <<HERE;
    <input type="checkbox" name="fjss_enabled_sort_page" id="fjss_enabled_sort_page" value="1"<mt:if name="fjss_enabled_sort_page" eq="1"> checked="checked"</mt:if> /> <__trans phrase="Enable to sort pages and folders">
HERE
    }
    my $tmpl = <<HERE;
<mtapp:setting
    id="fjss_init_sort_order"
    label="<__trans phrase="Initialize sort order">">
$links
</mtapp:setting>

<mtapp:setting
    id="fjss_enabld_to_sort"
    label="<__trans phrase="Enable to sort">">
$checkboxes
</mtapp:setting>

<mtapp:setting
    id="fjss_enabled_drag_and_drop"
    label="<__trans phrase="Drag and drop">">
    <input type="checkbox" name="fjss_enabled_drag_and_drop" id="fjss_enabled_drag_and_drop" value="1"<mt:if name="fjss_enabled_drag_and_drop" eq="1"> checked="checked"</mt:if> /> <__trans phrase="Enable to drag and drop on sort">
</mtapp:setting>

<input type="hidden" name="fjss_auto_rebuild_entry" value="1" />
<input type="hidden" name="fjss_auto_rebuild_page" value="1" />
<input type="hidden" name="fjss_auto_rebuild_after_delete_entry" value="1" />
<input type="hidden" name="fjss_auto_rebuild_after_delete_page" value="1" />

HERE
    $tmpl;
}

1;
