package SuperSort::L10N::ja;

use strict;
use base 'SuperSort::L10N::en_us';
use vars qw( %Lexicon );

%Lexicon = (
    # common
    'blog' => 'ブログ',
    'website' => 'ウェブサイト',
    'category' => 'カテゴリ',
    'folder' => 'フォルダ',
    'entry' => 'ブログ記事',
    'page' => 'ウェブページ',
    'categories' => 'カテゴリ',
    'folders' => 'フォルダ',
    'entries' => 'ブログ記事',
    'pages' => 'ウェブページ',
    'Category' => 'カテゴリ',
    'Folder' => 'フォルダ',

    # SuperSort.pl
    'Hajime Fujimoto' => '藤本　壱',
    'This plugin enables you to sort entries, pages, categories and folders.' => 'ブログ記事／ウェブページ／カテゴリ／フォルダを並べ替える機能を追加します。',
    'Initialize sort order' => '並び順の初期設定',
    'Categories and entries' => 'カテゴリとブログ記事',
    'Folders and pages' => 'フォルダとウェブページ',
    'Initialize sort order of categories and entries' => 'カテゴリとブログ記事の並び順の初期化',
    'Initialize sort order of folders and pages' => 'フォルダとウェブページの並び順の初期化',
    'Enable to sort' => '並べ替えの許可',
    'Enable to sort entries and categories' => 'ブログ記事とカテゴリの並べ替えを許可する',
    'Enable to sort pages and folders' => 'ウェブページとフォルダの並べ替えを許可する',
    'Rebuild adjacent entries' => '隣接するブログ記事の再構築',
    'Rebuild adjacent entries after entry was saved' => 'ブログ記事を保存したときに、隣接するブログ記事を再構築する',
    'Rebuild adjacent entries after entry was deleted' => 'ブログ記事を削除したときに、隣接するブログ記事を再構築する',
    'Rebuild adjacent pages' => '隣接するウェブページの再構築',
    'Rebuild adjacent pages after page was saved' => 'ウェブページを保存したときに、隣接するウェブページを再構築する',
    'Rebuild adjacent pages after page was deleted' => 'ウェブページを削除したときに、隣接するウェブページを再構築する',
    'Please initialize sort order.' => 'まず並び順を初期化してください。',
    'Drag and drop' => 'ドラッグアンドドロップ',
    'Enable to drag and drop on sort' => 'ドラッグアンドドロップでの並べ替えを許可する',
    'Synchronize with Movable Type 5.1' => 'Movable Type 5.1と同期',
    'Enable to synchronize with Movable Type 5.1 navive sorting function' => 'Movable Type 5.1標準の並べ替え機能と同期する',
    'Remove orphan categories' => '親がないカテゴリを削除します。',

    # lib/SuperSort/Initialize.pm
    'Root category' => 'ルートカテゴリ',
    'Root folder' => 'ルートフォルダ',
#    'Setting order number of categories and folders is successfully completed.' => 'カテゴリとフォルダの並び順の設定が正常に終了しました。',
    'You are not an administrator.' => '管理者権限がありません',
    'No name' => '無題',

    # lib/SuperSort/Sort.pm
    'Delete [_1] error.' => '[_1]の削除に失敗しました。',
    'No title' => '題名なし',

    # lib/SuperSort/Callback.pm
    'Save [_1] sort order error.' => '[_1]の並び順を保存することができませんでした。',

    # lib/SuperSort/Transformer.pm
    'Sort folders and pages' => 'フォルダとウェブページの並べ替え',
    'Sort categories and entries' => 'カテゴリとブログ記事の並べ替え',

    # lib/SuperSort/ContextHandler.pm
    "[_1] '[_2]' doesn't exist." => '[_1]「[_2]」は存在しません。',
    "[_1] whose id is [_2] doesn't exist." => 'IDが[_2]の[_1]は存在しません。',

    # tmpl/init_setting.tmpl
    'Initialization of sort order of [_1] and [_2]' => '[_1]と[_2]の並び順の初期化',
    'Many data are modified by this operation.\nFor an unexpected situation, please back up all data by all means.' => 'この操作によって多くのデータが更新されます。\n万が一に備えて、データを必ずバックアップしてください。',
    'Base [_1] to initialize sort order.' => '基点の[_1]',
    'Initialize sub [_1] recursively.' => 'サブ[_1]を再帰的に処理する',
    'Root [_1]' => 'ルート[_1]',
    'Sort order of [_1].' => '[_1]の並び順',
    'By [_1] label' => '[_1]の名前順',
    'By [_1] label (reverse)' => '[_1]の名前の逆順',
    'Same as [_1] order of Movable Type 5.1' => 'Movable Type 5.1の[_1]の並び順に合わせる',
    'By [_1] title' => '[_1]のタイトル順',
    'By [_1] title (reverse)' => '[_1]のタイトルの逆順',
    'By [_1] date' => '[_1]の日付順',
    'By [_1] date (reverse)' => '[_1]の日付の逆順',
    'Keep current order if possible' => '現状の並び順をなるべく維持',
    'No sort' => '並べ替えを行わない',

    # tmpl/init.tmpl
    'Initialization of sort order of [_1] and [_2]' => '[_1]と[_2]の並び順の初期化',
    'Sort order of sub [_1] is initialized' => 'サブ[_1]の並び順を初期化しました。',
    'Sort order of [_1]' => '[_1]の並び順',
    'is initialized' => 'を初期化しました。',
    'Initializing sort order is successfully finished.' => '並び順の初期化が終了しました。',
    'Initializing sort order failured.' => '並び順の初期化に失敗しました。',
    'Movable Type 5 native [_1] sort order was successfully saved.' => 'Movable Type 5標準の[_1]の並び順を保存しました。',

    # tmpl/sort.tmpl
    'Date' => '日付',
    'Author' => 'ユーザー',
    'Root' => 'ルート',
    'Saved sort order of [_1] and [_2].' => '[_1]と[_2]の並び順を保存しました。',
    'Deleted [_1].' => '[_1]を削除しました。',
    'Sort order of [_1] and [_2] was not changed.' => '[_1]と[_2]の並び順は変わっていません。',
    'Rebuild [_1].' => '[_1]を再構築してください。',
    'Now loading' => '読み込み中です。',
    'Sort [_1] and [_2]' => '[_1]と[_2]の並べ替え',
    'There are no [_1] and [_2].' => '[_1]と[_2]がありません。',
    'Loading [_1]' => '[_1]の読み込み',
    'Loading [_1] is finished.' => '[_1]を読み込みました。',
    'Load [_1] error' => '[_1]の読み込みに失敗しました。',
    'Create new root [_1]' => 'ルート[_1]を新規作成',
    'Create new [_1] in root [_2]' => 'ルート[_2]に[_1]を新規作成',
    'Create new [_1] in this [_2]' => 'この[_2]に[_1]を新規作成',
    'Same [_1] already exists in [_2] move to.' => '移動先の[_2]に同じ[_1]があります。',
    "This [_1] exists in other [_2], so this [_1] can't move to root [_2]" => 'この[_1]は他の[_2]にもありますので、ルート[_2]に移動することはできません。',
    'Same name sub category already exists in category move to.' => '同名のサブカテゴリが移動先のカテゴリにあります。',
    '(No title)' => '(無題)',
    'Open [_1]' => '[_1]を開く',
    'Close [_1]' => '[_1]を閉じる',
    'Top' => '先頭',
    'Bottom' => '最後',
    'Up' => '上',
    'Down' => '下',
    'Right click to show context menu' => '右クリックでコンテキストメニューを表示',
    'Move to upper [_1]' => '上の階層の[_1]へ移動',
    'Move to lower [_1]' => '下の階層の[_1]へ移動',
    'Sort order is not saved yet. Please save.' => '並び順をまだ保存していません。保存してください。',
    'Now saving sort order' => '並び順の保存中です。',
    'Create sub [_1]' => 'サブ[_1]の作成',
    'Edit this [_1]' => '[_1]の編集',
    'Delete this [_1]' => '[_1]の削除',
    'View this [_1]' => '[_1]の表示',
    "This [_1] includes [_2] or sub [_3]." => "この[_1]には[_2]またはサブ[_3]があります。",
    "Are you sure to delete this [_1] ?" => "この[_1]を削除しても良いですか？",
    'Loading sub [_1]' => 'サブ[_1]の読み込み中です',
    'Loading [_1] : ' => '[_1]を読み込み中です : ',
    'Now expanding other [_1]. Please wait.' => '他の[_1]を開いているところです。開き終わるまでお待ちください。',

    # tmpl/save.tmpl
    'Save information of moved [_1] and [_2].' => '移動した[_1]と[_2]の情報を保存します',
    'Save information of moved [_1] and [_2] failured.' => '移動した[_1]と[_2]の情報を保存するのに失敗しました。',
    'Check whether [_1] or [_2] order was changed' => '[_1]または[_2]の並び順が変更されたかどうかを調べています',
    'Save sort order of [_1]' => '[_1]の並び順を保存します',
    'Saving sort order of [_1] and [_2]' => '[_1]と[_2]の並び順の保存',
    'Save sort order of [_1] failured.' => '[_1]の並び順の保存に失敗しました。',
    'Save Movable Type 5.1 native sort order of [_1]' => 'Movable Type 5.1標準の[_1]の並び順の情報を保存します',
    'Save Movable Type 5.1 native sort order of [_1] failured.' => 'Movable Type 5.1標準の[_1]の並び順の情報を保存するのに失敗しました。',

    # tmpl/select_cat.tmpl
    'Select [_1] to move' => '移動先の[_1]の選択',

    # system_config.tmpl
    'Move to Movable Type 5.1' => 'Movable Type 5.1へ移行',
    'Move all order info to Movable Type 5.1' => 'すべての並び順の情報をMovable Type 5.1へ移行',
    'Move order info of selected websites and / or blogs to Movable Type 5.1' => '選択したウェブサイトとブログの並び順の情報をMovable Type 5.1へ移行',

    # select_blogs.tmpl
    'Select websites / blogs' => 'ウェブサイト／ブログを選択',
    'Website / Blog' => 'ウェブサイト／ブログ',

    # move_start.tmpl
    'Move order info to Movable Type 5.1' => '並び順の情報をMovable Type 5.1に移行',
    "Moved sort order information of [_1] '[_2]'." => '[_1]「[_2]」の並び順の情報を移行しました。',
    'Moving sort order information finished.' => '並び順の情報の移行を完了しました。',
    'Error occured : [_1].' => 'エラーが発生しました。 ： [_1]',
);

if (MT->version_number >= 6) {
    $Lexicon{'entry'} = '記事';
    $Lexicon{'entries'} = '記事';
    $Lexicon{'This plugin enables you to sort entries, pages, categories and folders.'} = '記事／ウェブページ／カテゴリ／フォルダを並べ替える機能を追加します。';
    $Lexicon{'Categories and entries'} = 'カテゴリと記事';
    $Lexicon{'Initialize sort order of categories and entries'} = 'カテゴリと記事の並び順の初期化';
    $Lexicon{'Enable to sort entries and categories'} = '記事とカテゴリの並べ替えを許可する';
    $Lexicon{'Rebuild adjacent entries'} = '隣接する記事の再構築';
    $Lexicon{'Rebuild adjacent entries after entry was saved'} = '記事を保存したときに、隣接する記事を再構築する';
    $Lexicon{'Rebuild adjacent entries after entry was deleted'} = '記事を削除したときに、隣接する記事を再構築する';
    $Lexicon{'Sort categories and entries'} = 'カテゴリと記事の並べ替え';
}

1;
