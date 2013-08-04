package SortCatFld;
use strict;

sub Sort {
    require MT;
    require MT::Blog;
    require MT::Request;

    my $blog_id = $MT::Template::Tags::Category::a->blog_id;
    my $class = $MT::Template::Tags::Category::a->class;
    my $req = MT::Request->instance;
    my $sorted_cats = $req->stash('SortCatFldMover::SortedCats::' . $class . '::' . $blog_id);
    unless(defined($sorted_cats)) {
        $sorted_cats = {};
        my $blog = MT->model('blog')->load($blog_id);
        my $order = 1;
        my @blog_cat_order_a = split ',', $blog->meta($class . '_order');
        for (my $i = 0; $i < scalar(@blog_cat_order_a); $i++) {
            $sorted_cats->{$blog_cat_order_a[$i]} = $i;
        }
        $req->stash('SortCatFldMover::SortedCats::' . $class . '::' . $blog_id, $sorted_cats);
    }

    $sorted_cats->{$MT::Template::Tags::Category::a->id} <=>
    $sorted_cats->{$MT::Template::Tags::Category::b->id};
}

1;
