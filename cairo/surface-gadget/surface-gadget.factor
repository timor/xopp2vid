USING: accessors cairo cairo-gadgets cairo-gadgets.private cairo.ffi images
images.viewer kernel libc locals math math.rectangles sequences ui.gadgets
ui.render ;

IN: cairo.surface-gadget

! * Mixin for surface element gadgets
MIXIN: cairo-render-gadget
GENERIC: pref-rect* ( gadget -- rect )

: prefer-loc ( gadget -- )
    [ pref-rect* loc>> ] keep loc<< ;
M: cairo-render-gadget pref-rect*
    children>> [ pref-rect* ] [ rect-union ] map-reduce ;
M: cairo-render-gadget pref-dim*
    pref-rect* dim>> ;
M: cairo-render-gadget layout*
    [ prefer ]
    [ prefer-loc ] bi ;
M: cairo-render-gadget draw-gadget*
    render-cairo* ;

! NOTE: The loc>> field is for things like collision detection.  The gadgets are
! responsible for rendering to the correct location themselves!
! TODO: use the image-control and the cairo-image as model

! * Cairo Container Gadget
SPECIALIZED-ARRAY: uchar
TUPLE: cairo-surface-gadget < image-gadget surface buffer ;
INSTANCE: cairo-surface-gadget cairo-render-gadget

: <cairo-surface-gadget> ( -- gadget ) cairo-surface-gadget new ;

<PRIVATE
: release-resources ( gadget -- )
    [ dup [ cairo_surface_destroy f ] when ] change-surface
    [ dup [ free f ] when ] change-buffer
    drop ;

:: allocate-resources ( gadget -- )
    gadget dim>> :> dim
    dim product 4 * :> size
    size uchar malloc-array :> buffer
    buffer dim <image-surface> :> surface
    <image> dim >>dim buffer >>bitmap
    BGRA >>component-order
    ubyte-components >>component-type :> image
    gadget buffer >>buffer surface >>surface image >>image drop ;
PRIVATE>

! * Container methods
M: cairo-surface-gadget layout* ( gadget -- )
    [ release-resources ]
    [ allocate-resources ] bi ;
    ! [ layout-surface-elements ] tri ;

M: cairo-surface-gadget pref-dim* ( gadget -- dim )
    pref-rect* dim>> [ ceiling >integer ] map ;

M: cairo-surface-gadget graft*
    [ release-resources ]
    [ allocate-resources ] bi ;
M: cairo-surface-gadget ungraft* release-resources ;
M: cairo-surface-gadget draw-children
    dup surface>> [ call-next-method ] with-cairo-from-surface ;
! TODO: What's the best way to have the layout functionality from the mixin, but
! drawing logic from the parent-class?
M: cairo-surface-gadget draw-gadget*
    M\ image-gadget draw-gadget* execute( gadget -- ) ;

! : render-cairo-children ( gadget -- )
!     [ surface>> ] [ [  ] with-cairo-from-surface ]

! M: cairo-surface-gadget draw-gadget*
!     [ render-cairo-children ] [ call-next-method ] bi ;
