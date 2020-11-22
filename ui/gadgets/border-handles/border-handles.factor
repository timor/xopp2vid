USING: accessors arrays kernel math.rectangles math.vectors sequences ui.gadgets
ui.gadgets.wrappers ui.gestures ;

IN: ui.gadgets.border-handles
FROM: ui.gadgets.wrappers => wrapper ;

! * Container Gadget with overlapping child gadget at border
SINGLETONS: +north+ +south+ +west+ +east+ ;
TUPLE: border-handle < wrapper direction width ;

<PRIVATE
: square ( n -- dim ) dup 2array ;
: perpendicular ( orientation -- orientation )
    vertical = horizontal vertical ? ;

GENERIC: dir-orientation ( gadget direction -- orientation )
M: +east+ dir-orientation drop orientation>> ;
! M: +east+ dir-orientation drop orientation>> ;
M: +west+ dir-orientation drop orientation>> ;
M: +north+ dir-orientation drop orientation>> perpendicular ;
M: +south+ dir-orientation drop orientation>> perpendicular ;

GENERIC: handle-rect ( rect width orientation direction -- rect )
M: +west+ handle-rect drop [ [ dim>> ] [ square ] bi* ] dip set-axis { 0 0 } swap <rect> ;
M: +north+ handle-rect drop [ [ dim>> ] [ square ] bi* ] dip set-axis { 0 0 } swap <rect> ;
M: +east+ handle-rect drop
    [ [ [ dim>> ] [ square ] bi* ] dip set-axis ]
    [ [ [ dim>> ] dip v-n { 0 0 } ] [ perpendicular ] bi* set-axis ] 3bi
    swap <rect> ;
M: +south+ handle-rect drop
    [ [ [ dim>> ] [ square ] bi* ] dip set-axis ]
    [ [ [ dim>> ] dip v-n { 0 0 } ] [ perpendicular ] bi* set-axis ] 3bi
    swap <rect> ;
! M: +south+ handle-rect drop
!     [ [ [ dim>> ] [ square ] bi* ] dip set-axis ]
!     [ [ v-n { 0 0 } ] dip set-axis ] 3bi
!     offset-rect ;

: compute-handle-rect ( gadget -- rect )
    dup [ width>> ] [ dup direction>> [ dir-orientation ] keep ] bi
    handle-rect ;
    ! [ dir-orientation ] keep handle-rect ;
    ! gadget dim>> width square
    ! gadget dir-orientation set-axis

: handle-gadget ( gadget -- gadget )
    children>> second ;

: layout-handle ( gadget --  )
    [ compute-handle-rect ]
    ! dup [ width>> ] [ direction>> handle-rect ]
    [ handle-gadget set-rect-bounds ] bi ;

: maybe-hide ( gadget -- )
    dup visible?>> [ [ hide-gadget ] [ parent>> relayout-1 ] bi ] [ drop ] if ;

: maybe-show ( gadget -- )
    dup visible?>> not [ [ show-gadget ] [ parent>> relayout-1 ] bi ] [ drop ] if ;

: over-handle? ( point gadget -- ? )
    handle-gadget
    [ loc>> ] [ dim>> ] bi <rect>
    contains-point? ;

: border-handle-motion ( gadget -- )
    dup [ hand-rel ] [ over-handle? ] bi
    [ handle-gadget maybe-show ]
    [ handle-gadget maybe-hide ] if ;
PRIVATE>

M: border-handle layout*
    [ call-next-method ]
    [ layout-handle ] bi ;

! : <border-handle> ( gadget handle-gadget -- gadget )
!     swap border-handle new-wrapper swap f >>visible? add-gadget ;
:: new-border-handle ( gadget handle direction class -- gadget )
    gadget class new-wrapper
    20 >>width
    direction >>direction
    handle f >>visible? add-gadget ;

border-handle H{
     { motion [ border-handle-motion ] }
     { mouse-leave [ handle-gadget maybe-hide ] }
    ! { mouse-enter [ t >>active parent>> relayout-1 ] }
    ! { mouse-leave [ f >>active parent>> relayout-1 ] }
} set-gestures
