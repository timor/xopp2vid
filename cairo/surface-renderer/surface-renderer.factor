USING: accessors cairo cairo-gadgets cairo-gadgets.private images.viewer kernel
locals math.rectangles models models.arrow namespaces sequences stroke-unit.util
ui.gadgets ui.gadgets.desks ;

IN: cairo.surface-renderer

! * Mixin for surface element gadgets
! MIXIN: cairo-render-g
! M: cairo-render-gadget pref-rect*
!     children>> [ pref-rect* ] [ rect-union ] map-reduce ;
! M: cairo-render-gadget pref-dim*
!     pref-rect* dim>> ;
! M: cairo-render-gadget layout*
!     [ prefer ]
!     [ prefer-loc ] bi ;
! M: cairo-render-gadget draw-gadget*
!     render-cairo* ;

! NOTE: The loc>> field is for things like collision detection.  The gadgets are
! responsible for rendering to the correct location themselves!
! TODO: use the image-control and the cairo-image as model

! SPECIALIZED-ARRAY: uchar
! TUPLE: cairo-surface < disposable surface buffer image ;
! M: cairo-surface dispose*
!     [ surface>> cairo_surface_destroy ] [ buffer>> free ] bi ;

! : <cairo-surface-gadget> ( -- gadget ) cairo-surface-gadget new ;

! <PRIVATE
! : release-resources ( gadget -- )
!     [ dup [ cairo_surface_destroy f ] when ] change-surface
!     [ dup [ free f ] when ] change-buffer
!     drop ;

! :: allocate-resources ( gadget -- )
!     gadget dim>> :> dim
!     dim product 4 * :> size
!     size uchar malloc-array :> buffer
!     buffer dim <image-surface> :> surface
!     <image> dim >>dim buffer >>bitmap
!     BGRA >>component-order
!     ubyte-components >>component-type :> image
!     gadget buffer >>buffer surface >>surface image >>image drop ;
! PRIVATE>

! : <cairo-surface> ( dim -- obj )
!     cairo-surface new-disposable swap
!     dim product 4 * :> size
!     size uchar malloc-array :> buffer
!     buffer dim <image-surface> :> surface
!     <image> dim >>dim buffer >>bitmap
!     BGRA >>component-order
!     ubyte-components >>component-type :> image
!     gadget buffer >>buffer surface >>surface image >>image drop ;

: render-cairo-sequence ( seq -- image )
    [ pref-rect-dim ]
    [| dim seq | dim [ current-cairo set seq [ render-cairo* ] each ] make-bitmap-image ] bi ;

:: <cairo-renderer> ( seq -- model gadget )
    ! seq [ pref-rect* ] [ rect-union ] map-reduce
    ! rect-extent nip ceiling-dim :> dim
    seq <model> dup
    [ render-cairo-sequence ] <arrow> <image-control> ;
! image-control gadget.  Model is a an object that implements the
! render-cairo* and pref-rect* generic
TUPLE: cairo-image < image-control surface ;
: render-cairo-elements ( gadget -- )
    control-value
    dup surface>> [ render-cairo* ] with-cairo-from-surface ;

! M: cairo-image
! M: cairo-image draw-gadget*
!     [ render-cairo* ]
!     [  ]
!     [ call-next-method ]

! ! * Container methods
! M: cairo-surface-gadget layout* ( gadget -- )
!     [ release-resources ]
!     [ allocate-resources ] bi ;
!     ! [ layout-surface-elements ] tri ;

! M: cairo-surface-gadget pref-dim* ( gadget -- dim )
!     pref-rect* dim>> [ ceiling >integer ] map ;

! M: cairo-surface-gadget graft*
!     [ release-resources ]
!     [ allocate-resources ] bi ;
! M: cairo-surface-gadget ungraft* release-resources ;
! M: cairo-surface-gadget draw-children
!     dup surface>> [ call-next-method ] with-cairo-from-surface ;
! ! TODO: What's the best way to have the layout functionality from the mixin, but
! ! drawing logic from the parent-class?
! M: cairo-surface-gadget draw-gadget*
!     M\ image-gadget draw-gadget* execute( gadget -- ) ;

! : render-cairo-children ( gadget -- )
!     [ surface>> ] [ [  ] with-cairo-from-surface ]

! M: cairo-surface-gadget draw-gadget*
!     [ render-cairo-children ] [ call-next-method ] bi ;
