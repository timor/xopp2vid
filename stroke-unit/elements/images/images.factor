USING: accessors arrays base64 cairo-gadgets cairo.ffi combinators images
images.loader images.normalization images.png kernel math math.parser
math.rectangles stroke-unit.elements stroke-unit.util ui.gadgets.desks xml.data
xml.traversal ;

IN: stroke-unit.elements.images

PREDICATE: image-elt < tag name>> main>> "image" = ;
SLOT: left
SLOT: right
SLOT: top
SLOT: bottom
M: image-elt left>> "left" attr string>number ;
M: image-elt right>> "right" attr string>number ;
M: image-elt top>> "top" attr string>number ;
M: image-elt bottom>> "bottom" attr string>number ;
M: image-elt pref-rect*
    {
        [ left>> ]
        [ top>> 2array ]
        [ right>> ]
        [ bottom>> 2array ]
    } cleave 2array rect-containing ;
M: image-elt element-rect pref-rect* ;
: png-data ( image-tag -- data ) children>string base64> ;

: image-elt-width ( image-elt -- n ) [ right>> ] [ left>> ] bi - ; inline
: image-elt-height ( image-elt -- n ) [ bottom>> ] [ top>> ] bi - ; inline

M:: image-elt render-cairo* ( img -- )
    img png-data png-image load-image* BGRA reorder-components
    [| img-surface |
     ! cairo_matrix_t <struct> :> matrix
     ! cr matrix cairo_get_matrix
     [
         img-surface cairo_image_surface_get_width :> width
         img-surface cairo_image_surface_get_height :> height
         cr CAIRO_OPERATOR_OVER cairo_set_operator
         img image-elt-width width /f :> xFactor
         img image-elt-height height /f :> yFactor
         cr xFactor yFactor cairo_scale
         cr img-surface img left>> xFactor /f img top>> yFactor /f cairo_set_source_surface
         cr cairo_paint
     ] with-saved-cairo-matrix
     ! cr matrix cairo_set_matrix
    ] with-factor-image-surface ;
