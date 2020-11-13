USING: accessors calendar combinators.short-circuit controls.animation
images.viewer kernel locals math math.functions models models.arrow
models.arrow.smart models.product models.range sequences
sequences.generalizations ui.gadgets ui.gadgets.packs ;

IN: images.sequence-viewer

: seq-range ( seq -- range ) [ 0 0 0 ] dip length 1 - 1 <range> ;

! TUPLE: item < product ;
! : item-seq ( item -- model ) dependencies>> first ;
! : item-index ( item -- model ) dependencies>> second ;

! : item-sequence ( item -- seq ) item-seq value>> ;
! : item-index-value ( item -- i ) item-index value>> ;
! : item-current ( item --  elt ) [ item-index ] [ item-sequence ] bi nth ;

! ! : <item> ( seq -- model )
! !     <model> 0 <model> 2array item new-product ;

! ! TUPLE: select < model range-model seq-model ;
! :: <selector> ( seq -- range-model item-model )
!     seq [ seq-range [ first floor >integer ] <arrow> ] keep 2array item new-product ;
!     ! [ item-current ] <arrow> ;
!     ! 2dup f select new-model
!     ! 3dup [ range-model<< ] [ seq-model<< ] bi-curry bi* ;
!     ! [ add-dependency ] curry bi@ ;

! :: update-selector ( seq range-model item-model -- )

!     seq seq-range

! M: select model-changed nip
!     [ range-omode ]

! : <demux> ( model quot -- model )
!     inputs '[ _ ]

! : <range-select> ( range-model seq-model -- model )
!     [ [ first floor >integer ] dip nth ] <smart-arrow> ;
:: <index-range> ( seq-model -- range-model )
    0 <model> 0 <model> 0 <model> seq-model [ length 1 - ] <arrow> 1 <model> 5 narray range new-product ;

: nth-or-last ( n seq -- elt )
    { [ ?nth ] [ last ] } 1|| ;

: <item> ( seq-model range-model -- elt-model )
    [ first floor >integer swap nth-or-last ] <smart-arrow> ;

: <selector> ( seq-model -- elt-model range-model )
    dup <index-range> [ <item> ] keep ;

TUPLE: image-player < pack animation ;
! M: image-player hide-controls children>> second hide-gadget ;
! M: image-player hide-controls children>> second show-gadget ;

! :: rebuild-animation ( seq-model player -- )
!     seq-model value>> seq-range value>> player animation>> set-control-value ;
    ! range seq <range-select> :> image-model
    ! range player fps>> recip seconds 1 <range-animation> :> animation
    ! player animation >>animation
    ! image-model player viewer>> set-model ;

! : new-image-player ( fps -- gadget )
!     image-player new vertical >>orientation swap >>fps
!     image-control new-image-gadget [ >>viewer ] [ add-gadget ] bi
!     f seq-range horizontal <slider> [ >>slider ]
: ensure-model ( x -- x )
    dup model? [ <model> ] unless ;

! : show-last-image ( player -- )
!     [ model>> value>> last ]
!     [ gadget-child ] bi
!     [ swap set-image drop ] [ relayout ] bi ;

:: <image-player> ( seq fps -- gadget )
    image-player new vertical >>orientation dup :> player
    seq ensure-model dup :> seq-model >>model
    seq-model <selector> :> ( elt-model range-mdl )
    range-mdl fps recip seconds 1 <range-animation> dup :> animation >>animation
    elt-model <image-control> add-gadget
    animation <animation-controls> add-gadget ;


    ! model seq <range-select> <image-control> [ add-gadget ]
    ! model fps recip seconds 1 <range-animation> [ <animation-controls> add-gadget ] [ >>animation ] bi ;

! TUPLE: image-player < pack stepper paused ;

! : start-image-player ( player -- )
!     [ stepper>> start-control ]
!     [ paused>> f swap set-model ] bi ;

! : stop-image-player ( player -- )
!     [ stepper>> stop-control ]
!     [ paused>> t swap set-model ] bi ;

! : toggle-image-player ( player -- )
!     dup paused>> value>>
!     [ start-image-player ] [ stop-image-player ] if ;

! <PRIVATE
! : <image-playback-button> ( player model -- gadget )
!     [ "⯈" "⏸" ? ] <arrow> <label-control> swap '[ drop _ toggle-image-player ] <button> ;
! PRIVATE>

! :: <image-player> ( seq fps -- gadget )
!     seq seq-range :> range
!     range fps recip 1 <range-stepper> :> stepper
!     image-player new vertical >>orientation dup :> player
!     stepper >>stepper
!     range [ first floor >integer seq nth ] <arrow> <image-control> add-gadget
!     t <model> [ >>paused ] [ player swap <image-playback-button> ] bi <shelf> swap add-gadget
!     range horizontal <slider> add-gadget add-gadget ;


! :: <image-sequence-viewer> ( seq -- model gadget )
!     0 0 0 seq length 1 - 1 <range> :> model
!     model dup [ first floor >integer seq nth ] <arrow> <image-control> ;

! TUPLE: image-player < image-control range animator ;

! : <paused-label> ( model -- gadget )
!     [ "⯈" "⏸" ? ] <arrow> <label-control> ;

! ! Return the button, slider and viewer gadgets
! :: <image-sequence-controls> ( seq fps -- button slider image-control )
!     0 0 0 seq length 1 - 1 <range> :> range
!     range [ first floor >integer seq nth ] <arrow>
!     image-player new-image-gadget* :> player
!     ! seq <image-sequence-viewer> :> ( range viewer )
!     fps recip seconds 1 range <range-animator> :> animator
!     range horizontal <slider> 1 >>line
!     animator paused>> <paused-label> [ drop animator toggle-animation ] <button>
!     player range >>range animator >>animator ;
!     ! animator paused>> <paused-label> [ drop animator toggle-animation ] <button> :> play/pause

! ! Animation is controlled using the animator slot

! ! TUPLE: image-player < pack range animator ;

! : pack-player-gadget ( button slider image-control pack -- pack )
!     swap add-gadget
!     [ <shelf> swap add-gadget swap add-gadget ] dip
!     swap add-gadget ;

! : <image-player> ( seq fps -- gadget )
!     <image-sequence-controls>
!     <pile> pack-player-gadget ;
!     ! [ <pile> swap add-gadget ] dip add-gadget ;
!     ! image-player new vertical >>orientation :> player
!     ! seq <image-sequence-viewer> :> ( range viewer )
!     ! range horizontal <slider> 1 >>line :> slider
!     ! fps recip seconds 1 range <range-animator> :> animator
!     ! player range >>range animator >>animator
!     ! animator paused>> <paused-label> [ drop animator toggle-animation ] <button> :> play/pause
!     ! viewer add-gadget
!     ! <shelf> play/pause add-gadget slider add-gadget
!     ! add-gadget ;
