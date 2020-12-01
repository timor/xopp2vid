USING: accessors assocs colors.constants combinators controls
images.viewer kernel math math.rectangles
math.vectors models models.arrow models.model-slots models.selection namespaces
sequences sets stroke-unit.clip-renderer stroke-unit.strokes stroke-unit.util
ui.gadgets ui.gadgets.buttons ui.gadgets.glass ui.gadgets.model-children
ui.gadgets.packs ui.gadgets.wrappers ui.gadgets.wrappers.rect-wrappers
sets
ui.gestures ui.pens.solid ;

IN: stroke-unit.clips.clip-maker

! * Gadget for grouping elements into clips

TUPLE: strokes-canvas < gadget zoom-m ;
MODEL-SLOT: strokes-canvas [ zoom-m>> ] zoom
INSTANCE: strokes-canvas model-children

M: strokes-canvas pref-dim*
    { 0 0 } swap [ rect-extent nip vmax ] each-child ;

: stroke-view ( stroke -- gadget )
    [ stroke-rect <model> ] [ stroke-image ] bi <image-gadget> <rect-wrapper> ;

M:: strokes-canvas child-model>gadget ( model gadget -- gadget )
    gadget zoom-model>> :> zoom-model
    model :> stroke
    stroke stroke-image <image-gadget> :> img
    gadget find-selection stroke img <selectable-wrapper> :> sel-wrapper
    zoom-model stroke stroke-rect '[ _ swap rect-scale ] <arrow> sel-wrapper <rect-wrapper> ;

M: strokes-canvas add-model-children swap add-gadgets ;

: contained-strokes ( rect gadget -- seq )
    children>> [ contains-rect? ] with filter
    [ gadget-child item>> ] map ;

: <strokes-canvas> ( strokes-model -- gadget )
    strokes-canvas new swap >>model
    1 <model> >>zoom-m ;

: zoom-strokes-canvas ( gadget -- )
    scroll-direction get second neg
    [ drop ]
    [ swap [ swap 0.5 * + ] change-zoom drop ] if-zero ;

strokes-canvas H{
    { mouse-scroll [ zoom-strokes-canvas ] }
} set-gestures

TUPLE: stroke-selector < ui.gadgets.wrappers:wrapper selection last-value ;

INSTANCE: stroke-selector has-selection
INSTANCE: stroke-selector drag-control

: drag-box-gadget ( gadget -- gadget ) children>> second ;
M: stroke-selector drag-started nip
    [ hand-rel ] keep
    drag-box-gadget
    { [ loc<< ]
      [ { 0 0 } swap dim<< ]
      [ show-gadget ]
      [ relayout ] } cleave ;

: items-in-box ( gadget -- items )
    [ drag-box-gadget ] [ gadget-child ] bi contained-strokes ;
    ! [ drag-box-gadget ] [ selection>> items>> ] bi
    ! [ stroke-rect contains-rect? ] with filter ;

: hide-drag-box ( gadget -- )
    drag-box-gadget [ hide-gadget ] [ relayout ] bi ;

: if-drag ( ..a true: ( ..a -- ..b ) false: ( ..a -- ..b ) -- ..b )
    ! drag-loc distance 1 > [ drop call ] [ nip call ] if ; inline
    [ drag-loc norm 1 > ] 2dip if ; inline

M: stroke-selector drag-ended nip
    [ [ items-in-box ]
      [ selection>> select-items ]
      [ hide-drag-box ] tri ]
    [ drop ] if-drag ;

: ctrl-drag-ended ( gadget -- )
   [ {
        [ items-in-box ]
        [ selection>> selected>> union ]
        [ selection>> select-items ]
        [ hide-drag-box ]
       } cleave ] [ drop ] if-drag ;

M: stroke-selector drag-value-changed drag-box-gadget
    [ dim<< ] [ relayout ] bi ;

M: stroke-selector layout*
    ! [
        call-next-method ;
    ! ] keep
    ! [ dim>> ] [ drag-box-gadget ] bi dim<< ;

! : <drag-surface> ( -- gadget )
!     { 0 0 } clone <model> stroke-selector new-control
!     drag-box new-gadget

: <stroke-selector> ( strokes -- gadget )
    <model>
    [ <strokes-canvas> stroke-selector new-wrapper ]
    [ <selection> ] bi t >>multi? >>selection
    { 0 0 } clone <model> >>model
    <gadget> COLOR: black <solid> >>boundary add-gadget ;

stroke-selector drag-control-gestures
H{
    { T{ button-up f { C+ } 1 } [ ctrl-drag-ended ] }
    { T{ button-down f { C+ } 1 } [ begin-drag ] }
} assoc-union
set-gestures

! * Glass layer selector

TUPLE: clip-maker < pack callback ;

: remove-canvas-strokes ( gadget -- strokes )
    gadget-child selection>>
    [ selected>> dup ]
    [ clear-selected ]
    [ [ swap diff ] change-items drop ] tri ;

: apply-callback ( gadget -- )
    ! [ gadget-child selection>> selected>> ]
    [ remove-canvas-strokes ]
    [ callback>> ] bi call( strokes -- ) ;

! : clear-stroke-selection ( gadget -- )
!     gadget-child selection>> clear-selected ;

! : close-clip-maker ( gadget -- )
!     [ gadget-child selection>> selected>> ]
!     [ hide-glass ]
!     [ callback>> ] tri call( strokes -- ) ;

:: <clip-maker> ( strokes callback -- gadget )
    clip-maker new vertical >>orientation
    dup :> maker
    COLOR: white <solid> >>interior
    COLOR: black <solid> >>boundary
    callback >>callback
    strokes <stroke-selector> add-gadget
    <shelf>
    "Apply" [ drop maker apply-callback ] <roll-button> add-gadget
    "Close" [ hide-glass ] <roll-button> add-gadget add-gadget ;

: show-clip-maker ( owner strokes callback -- )
    <clip-maker> <zero-rect> show-glass ;
