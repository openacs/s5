ad_library {
    S5 - main libraray classes and objects

    @creation-date 2007-05-01
    @author Gustaf Neumann
    @cvs-id $Id$
}
::xo::db::require package xowiki

namespace eval ::s5 {
  ::xo::PackageMgr create ::s5::Package \
      -package_key "s5" -pretty_name "S5" \
      -superclass ::xowiki::Package

  # To provide downward compatibility with e.g. xowiki form oacs-5-3, 
  # we set the package_key via instvar.
  # TODO: The package-key should be set via "-package_key s5" 
  # during the above create statement
  ::s5::Package set package_key s5 

  Package instproc init {} {
    set rich_text_spec {richtext(richtext),nospell,optional
      {label Content}
      {html {style {width: 100%}}}
      {options {editor xinha plugins {Stylist OacsFs} height 350px javascript {
 
     xinha_config.stylistLoadStylesheet('/resources/s5/s5-xinha.css');
    }}}}

    ::xo::cc set_parameter widget_specs [list *,text $rich_text_spec]
    next
  }
}

namespace eval ::xowiki::portlet {
  #
  # Create an includelet called s5, which behaves similar 
  # to the book includelet (default), or produces an S5 slide-show,
  # when slideshow flag is true.
  #
  Class create s5 \
      -superclass ::xowiki::Portlet \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-category_id}
          {-slideshow:boolean false}
          {-style standard}
          {-menu_buttons "edit-item-button create-item-button delete-item-button"}
        }}
      }

  s5 instproc render {} {
    my get_parameters
    set page [my set __including_page]

    my set package_id $package_id
    my set style $style
    my set page $page

    lappend ::xowiki_page_item_id_rendered [$page item_id] ;# prevent recursive rendering

    set extra_where_clause ""
    set cnames ""
    if {[info exists category_id]} {
      foreach {cnames extra_where_clause} [my category_clause $category_id] break
    }

    set pages [::xowiki::Page instantiate_objects -sql \
        "select page_id, page_order, name, title, item_id \
		from xowiki_page_live_revision p \
		where parent_id = [$package_id folder_id] \
		and not page_order is NULL $extra_where_clause \
		[::xowiki::Page container_already_rendered item_id]" ]
    $pages mixin add ::xo::OrderedComposite::IndexCompare
    $pages orderby page_order
    if {$slideshow} {
      return [my render_slideshow $pages $cnames]
    } else {
      return [my render_overview $pages $cnames $menu_buttons]
    }
  }

  s5 instproc slideshow_header {-title -creator -footer -s5dir} {
    return [subst {<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>$title</title>
<!-- metadata -->
<meta name="generator" content="xowiki S5" />
<meta name="version" content="\$Id\$" />
<meta name="presdate" content="20050128" />
<meta name="author" content="$creator" />
<!-- configuration parameters -->
<meta name="defaultView" content="slideshow" />
<meta name="controlVis" content="hidden" />
<!-- style sheet links -->

<link rel="stylesheet" href="$s5dir/slides.css" type="text/css" media="projection" id="slideProj" />
<link rel="stylesheet" href="$s5dir/outline.css" type="text/css" media="screen" id="outlineStyle" />
<link rel="stylesheet" href="$s5dir/print.css" type="text/css" media="print" id="slidePrint" />
<link rel="stylesheet" href="$s5dir/opera.css" type="text/css" media="projection" id="operaFix" />
<!-- embedded styles -->
<style type="text/css" media="all">
.imgcon {width: 525px; margin: 0 auto; padding: 0; text-align: center;}
#anim {width: 270px; height: 320px; position: relative; margin-top: 0.5em;}
#anim img {position: absolute; top: 42px; left: 24px;}
img#me01 {top: 0; left: 0;}
img#me02 {left: 23px;}
img#me04 {top: 44px;}
img#me05 {top: 43px;left: 36px;}
</style>
<!-- S5 JS -->
<script src="$s5dir/slides.js" type="text/javascript"></script>
</head>
<body>

<div class="layout">
<div id="controls"><!-- DO NOT EDIT --></div>
<div id="currentSlide"><!-- DO NOT EDIT --></div>
<div id="header"></div>

<div id="footer">
$footer
</div>
</div>

<div class="presentation">
}]
  }

  s5 instproc render_slideshow {pages cnames} {
    my instvar package_id style page
    ::xo::cc set_parameter master 0

    set output [my slideshow_header \
                    -title [$page set title] \
                    -creator [$page set creator] \
                    -footer [$page include_portlet "footer -decoration none"] \
                    -s5dir "/resources/s5/$style/ui/default"]

    if {$cnames ne ""} {
      #append output "<div class='filter'>Filtered by categories: $cnames</div>"
    }
    foreach o [$pages children] {
      $o instvar page_order title page_id name title 
      set level [expr {[regsub {[.]} $page_order . page_order] + 1}]
      set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id $page_id]
      $p destroy_on_cleanup
      #$p set render_adp 0
      set content [$p get_content]
      set content [string map [list "\{\{" "\\\{\{"] $content]
      append output "<div class='slide'>" \
          <h1> $title </h1> \n \
          $content \
          </div> \n
    }
    return $output
  }

  s5 instproc render_overview {pages cnames menu_buttons} {
    my instvar package_id page
    set output ""
    if {$cnames ne ""} {
      append output "<div class='filter'>Filtered by categories: $cnames</div>"
    }
    set return_url [::xo::cc url]

    foreach o [$pages children] {
      $o instvar page_order title page_id name title 
      set level [expr {[regsub {[.]} $page_order . page_order] + 1}]
      set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id $page_id]
      $p destroy_on_cleanup

      set menu [list]
      foreach b $menu_buttons {
	set html [$p include_portlet $b]
        if {$html ne ""} {lappend menu $html}
      }
      set menu "<div style='float: right'>[join $menu {&nbsp;}]</div>"
      $p set unresolved_references 0
      #$p set render_adp 0
      set content [$p get_content]
      set content [string map [list "\{\{" "\\\{\{" "\\@" "\\\\@"] $content]
      my log content=$content
      regexp {^.*:([^:]+)$} $name _ anchor
      append output "<h$level class='book'>" \
          $menu \
          "<a name='$anchor'></a>$page_order $title</h$level>" \
          $content
    }
    return $output
  }
}
