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

namespace eval ::xowiki::includelet {
  #
  # Create an includelet called s5, which behaves similar 
  # to the book includelet (default), or produces an S5 slide-show,
  # when slideshow flag is true.
  #
  ::xowiki::IncludeletClass create s5 \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-category_id}
          {-slideshow:boolean false}
          {-pagenr 0}
          {-style standard}
          {-menu_buttons "view edit copy create delete"}
        }}
      }

  s5 instproc render {} {
    :get_parameters
    set page ${:__including_page}

    set :package_id $package_id
    set :style $style
    set :page $page

    lappend ::xowiki_page_item_id_rendered [$page item_id] ;# prevent recursive rendering

    set extra_where_clause ""
    set cnames ""
    if {[info exists category_id]} {
      lassign [:category_clause $category_id] cnames extra_where_clause
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
      return [:render_slideshow $pages $cnames $pagenr]
    } else {
      return [:render_overview $pages $cnames $menu_buttons]
    }
  }

  s5 instproc slideshow_header {-title -creator -footer -s5dir -presdate} {
    set header_stuff [::xo::Page header_stuff]
    return [subst {<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>$title</title>
<!-- metadata -->
<meta name="generator" content="xowiki S5" />
<meta name="version" content="\$Id\$" />
<meta name="presdate" content="$presdate" />
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
$header_stuff
<script type="text/javascript" src="/resources/ajaxhelper/yui/utilities/utilities.js" ></script>
<!--
<script type="text/javascript" src="http://yui.yahooapis.com/2.4.1/build/utilities/utilities.js" ></script>
-->
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

  s5 instproc render_slideshow {pages cnames pagenr} {
    :instvar package_id style page
    ::xo::cc set_parameter master 0

    set coverpage [:resolve_page_name en:cover]
    if {$coverpage eq ""} {
      set coverpage $page
    }
    set outtput ""

    if {$cnames ne ""} {
      #append output "<div class='filter'>Filtered by categories: $cnames</div>"
    }
    ::xo::cc set_parameter __no_footer 1
    set count 0
    foreach o [$pages children] {
      $o instvar page_order title page_id name title 
      set level [expr {[regsub {[.]} $page_order . page_order] + 1}]
      set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id $page_id]
      $p destroy_on_cleanup
      #$p set render_adp 0
      set content [$p get_content]
      #set content [string map [list "\{\{" "\\\{\{"] $content]
      set evenodd [expr {[incr count]%2 ? "even" : "odd"}]
      append output "<div class='slide $evenodd'>" \
          <h1> $title </h1> \n \
          $content \
          </div> \n
    } 
    # eval header here to get required header stuff
    set header [:slideshow_header \
                    -title [$coverpage set title] \
                    -creator [$coverpage set creator] \
                    -presdate [lindex [$coverpage set last_modified] 0] \
                    -footer [$page include "footer -decoration none"] \
                    -s5dir "/resources/s5/$style/ui/default"]

    # use YAHOO event management to allow multiple event listener, and ensure, this ones is after s5's
    append output "<script type='text/javascript'>
      var pagenr = $pagenr;

      function ngo() { go(pagenr); }

      YAHOO.util.Event.addListener(window, 'load', ngo);
    </script>\n"

    return $header$output
  }

  s5 instproc render_overview {pages cnames menu_buttons} {
    :instvar package_id page
    set output ""
    if {$cnames ne ""} {
      append output "<div class='filter'>Filtered by categories: $cnames</div>"
    }

    #set return_url [::xo::cc url]

    set count -1
    foreach o [$pages children] {
      $o instvar page_order title page_id name title 
      incr count

      set level [expr {[regsub {[.]} $page_order . page_order] + 1}]
      set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id $page_id]
      $p destroy_on_cleanup

      set pagenr_link "presentation?slideshow=1&pagenr=$count"
      set menu {}
      foreach b $menu_buttons {
	if {[info commands ::xowiki::includelet::$b] eq ""} {
	  set b $b-item-button
	}
        switch $b {
	  view-item-button {append b " -link $pagenr_link"}
	}
	set html [$p include "$b -book_mode true"]
	if {$html ne ""} {lappend menu $html}
      }

      set menu "<div style='float: right'>[join $menu {&nbsp;}]</div>"
      $p set unresolved_references 0
      #$p set render_adp 0
      set content [$p get_content]
      set content [string map [list "\\@" "\\\\@"] $content]
      #my log content=$content
      regexp {^.*:([^:]+)$} $name _ anchor
      append output "<h$level class='book'>" \
          $menu \
          "<a name='$anchor'></a><a href='$pagenr_link'>$page_order</a> $title</h$level>" \
          $content
    }
    return $output
  }
}


namespace eval ::xowiki::includelet {
  #
  # vertical spacer
  #
  ::xowiki::IncludeletClass create vspace \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-height ""}
          {-width ""}
        }}
      }

  vspace instproc render {} {
    :get_parameters
    if {$height ne ""} {
      set height "height: $height;"
    }
    if {$width ne ""} {
      set width "width: $width;"
    }
    return "<div style='$width $height'><!-- --></div>\n"
  }
}


if {![::xotcl::Object isclass ::xowiki::formfield::code_listing]} {
  #
  # code_listing was moved to xowiki.
  #
  # keep this definition just for backwards compatibility
  namespace eval ::xowiki::formfield {
    ###########################################################
    #
    # ::xowiki::formfield::code_listing
    #
    ###########################################################
    
    Class code_listing -superclass textarea -parameter {
      {rows 20}
      {cols 80}
    }
    code_listing instproc pretty_value {v} {
      [:object] do_substitutions 0
      return "<pre class='code'>[api_pretty_tcl [:value]]</pre>"
    }
  }
}
