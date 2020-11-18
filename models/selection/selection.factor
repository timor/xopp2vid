USING: accessors arrays kernel locals models models.arrow models.arrow.smart
models.product sequences ui.gadgets ;

IN: models.selection

GENERIC: handles-selection? ( gadget -- ? )
GENERIC: handle-selection ( i gadget -- )
M: gadget handles-selection? drop f ;

: find-selection ( gadget -- gadget/f )
    [ handles-selection? ] find-parent ;

GENERIC: selection-index ( gadget -- i )

: notify-selection ( gadget -- )
    dup find-selection
    [
        [ selection-index ]
        [ handle-selection ] bi*
    ] [ drop ] if* ;

! TUPLE: selection < models.product:product ;
! SLOT: items
! SLOT: index
! SLOT: selected

! : new-selection ( items-model index-model selected-model -- model )
!     3array selection new-product ;

! M: selection items>> dependencies>> first ;
! M: selection index>> dependencies>> second ;
! M: selection selected>> dependencies>> third ;

! :: <selection> ( items-model -- model )
!     0 <model> :> index-model
!     items-model index-model [ dupd clamp-index swap nth ] <?smart-arrow> :> selected-model
!     items-model index-model selected-model new-selection ;

! : select-item ( selection item -- )
!     over items>> compute-model index
!     [ swap index>> set-model ]
!     [ drop ] if* ;

! : select-nth ( selection n -- )
!     over items>> compute-model
!     swap clamp-index
!     swap index>> set-model ;

! : selected-index ( selection -- i )
!     index>> compute-model ;

! : selected-item ( selection -- obj )
!     selected>> compute-model ;

! : nofity-selection ( gadget item -- )
!     over find-selection
!     [ handle-selection ] [ 2drop ] if* ;
