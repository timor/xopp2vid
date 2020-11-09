USING: accessors cairo.surface-renderer kernel models sequences xml.traversal ;

IN: stroke-unit.page

! * Provide Container and Cairo context for stroke drawing

! : <page-gadget> ( page -- gadget )
!     <cairo-surface-gadget> swap
!     "stroke" deep-tags-named [ <stroke-gadget> add-gadget ] each ;
SLOT: elements
TUPLE: page-renderer model gadget ;

: <page-renderer> ( page -- obj )
    "layer" tags-named [ children-tags ] map concat
    <cairo-renderer> page-renderer boa ;

M: page-renderer elements<< model>> set-model ;

! ! Contains the cairo context at the time child gadget's draw-cairo* methods are called
! SYMBOL: stroke-page-cairo

! TUPLE: cairo-context cairo surface ;

! : with-gadget-cairo ( gadget quot: ( gadget -- ) -- )
!     dupd curry
!     [ cctx>> cairo>> current-cairo ] dip with-variable ; inline

! TUPLE: cairo-page < image-gadget cctx ;

! : add-cairo-gadget ( page gadget -- page )
!     over cctx>> >>cctx add-gadget ;

! : free-cctx ( page -- )
!     cctx>>
!     [ [ cairo>> cairo_destroy ] [ surface>> cairo_surface_destroy ] bi ] when* ;

! : update-cairo-context ( cairo-page -- )
!     dup free-cctx
!     [ cctx>> ] [ dim>> ] bi
!     [ CAIRO_FORMAT_ARGB32 ] dip first2 cairo_image_surface_create dup check-surface
!     [ <cairo> ] keep [ >>cairo ] [ >>surface ] bi* drop ;

! : clear-page ( cairo-page -- )
!     [
!         cr COLOR: white set-source-color
!         dim>> cr swap fill-rect
!     ] with-gadget-cairo ;

! M: cairo-page layout*
!     [ update-cairo-context ]
!     [ clear-page ] bi ;

! : surface>image ( surface -- image )
!     [ cairo_image_surface_get_width ]
!     [ cairo_image_surface_get_height 2array malloc-bitmap-data ]
!     [  ]


! M: cairo-page draw-gadget*
!     cctx>>



! TUPLE: cairo-page-child < gadget cctx ;
! M: cairo-page-child draw-gadget*
!     [ render-cairo* ] with-gadget-cairo ;
