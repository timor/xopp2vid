USING: sequences stroke-unit.clips ui.gadgets.desks ;

IN: stroke-unit.viewer

! * Gadget for viewing/manipulating pages/clips/strokes

! Lays out gadgets according to pref-rect* implementation

TUPLE: page-desk < desk clips timers ;

: <page-desk> ( clips -- gadget )
    [ <clip-viewer> ] map [ page-desk new-desk ] keep
    [ clip>> value>> ] map >>clips ;

: make-clip-start-timer ( duration clip-viewer -- timer )
    [ play-clip-viewer ] curry swap f <timer> ;

: schedule-clips ( viewers -- timers )
    instant swap
    [ [ over swap make-clip-start-timer ]
      [ swap [ clip>> value>> clip-duration time+ ] dip ] bi
    ] map nip ;

: reset-page-playback ( page-desk -- )
    dup timers>> [ stop-timer ] each
    children>> [
        [ reset-clip-viewer ]
        [ switch-to-editor ] bi
    ] each ;

: prepare-page-playback ( page-desk -- )
    dup
    [ reset-page-playback ]
    [ hide-controls ]
    [ children>> schedule-clips ] tri >>timers drop ;

: start-page-playback ( page-desk -- )
    [ timers>> ]

: stop-page-playback ( page-desk -- )
    [ reset-page-playback ]
    [ show-controls ] bi ;


! : find-clip-viewer ( page-desk clip-model -- gadget )
!     swap children>> [ clip>> = ] with find nip ;

! :: <clip-list> ( page-desk -- gadget )
!     page-desk clip-models>>
!     [| clip |
!      clip <clip-preview>
!      [ drop page-desk clip find-clip-viewer make-selected ]
!      <button>
!     ] map <pile> swap add-gadgets ;


! : <page-editor> ( clips -- gadget )
!     <page-desk> dup <clip-list>
!     swap horizontal <track> swap f track-add swap f track-add ;
