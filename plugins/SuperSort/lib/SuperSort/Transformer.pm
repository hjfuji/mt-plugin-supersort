#
# Transformer.pm
#
# 2008/10/20 1.00b1 Beta release
# 2012/07/20 1.20b2 For Movable Type 5.2
#
# Copyright(c) by H.Fujimoto
#
package SuperSort::Transformer;

use strict;

use MT;
use MT::Plugin;
use MT::Category;
use MT::Folder;

sub edit_category {
    my ($plugin, $cb, $app, $param, $tmpl) = @_;

    if ($app->param('init_parent')) {
        my $parent = $app->param('init_parent');
        my $host_node = $tmpl->getElementById('label');
        my $html = <<HERE;
<input type="hidden" name="init_parent" value="${parent}" />

HERE
        my $node = $tmpl->createTextNode($html);
        $tmpl->insertAfter($node, $host_node);
    }
}

sub edit_entry {
    my ($plugin, $cb, $app, $param, $tmpl) = @_;

    if ($app->param('init_cat_id')) {
        $param->{selected_category_loop} = [ $app->param('init_cat_id') ];
    }
}

1;
