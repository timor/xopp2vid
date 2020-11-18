USING: accessors calendar kernel math models models.range sequences ;

IN: stroke-unit.models.page-parameters


! SYMBOL: focused-clip-index

SLOT: draw-duration
SLOT: start-time
! All slots models
TUPLE: page-parameters current-time draw-scale timescale ;
: <page-parameters> ( -- obj )
    0 <model> 1 <model> 10 <model> page-parameters boa ;

: recompute-page-duration ( clip-diplays -- seconds )
    last [ start-time>> compute-model ]
    [ draw-duration>> compute-model duration>seconds ] bi + ;
! [ draw-duration>> compute-model duration>seconds ]
! map-sum ;

: <range-page-parameters> ( clip-displays -- range-model parameters )
    recompute-page-duration [ 0 0 0 ] dip 0 <range>
    dup range-model 1 <model> 10 <model> page-parameters boa ;

! All args models
: <clip-selection> ( clip-displays index -- clip-selection )
