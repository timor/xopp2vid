USING: accessors kernel math.rectangles math.vectors sequences stroke-unit.util
ui.gadgets ;

IN: ui.gadgets.desks

GENERIC: pref-rect* ( gadget -- rect )
GENERIC: pref-loc* ( gadget -- loc )

: pref-rect-loc-min ( seq -- loc )
    [ pref-loc* ] [ vmin ] map-reduce ;

M: gadget pref-loc*
    children>> [ pref-rect-loc-min ] [ "no-preferred location" throw ] if* ;

! calculates preferred dimension of sequence of objects implementing pref-rect*
: pref-rect-union ( seq -- rect )
    [ pref-rect* ] [ rect-union ] map-reduce ;

: pref-rect-dim ( seq -- dim )
    [ { 0 0 } ] [ pref-rect-union
                  rect-extent nip ceiling-dim ] if-empty ;

: prefer-loc ( gadget -- )
    dup pref-loc* >>loc drop ;

TUPLE: desk < gadget ;
! M: desk pref-dim* children>> pref-rect-dim ;
M: desk layout* [ [ prefer-loc ] [ prefer ] bi ] each-child ;
M: desk pref-dim* children>> pref-rect-dim ;

: new-desk ( gadgets class -- desk ) new swap add-gadgets ;
: <desk> ( gadgets -- gadget ) desk new-desk ;
