USING: accessors kernel namespaces sequences stroke-unit.elements
stroke-unit.strokes xml.syntax ;

IN: stroke-unit.clips

TUPLE: clip audio elements ;
: <clip> ( audio -- obj ) clip new swap >>audio V{ } clone >>elements ;

SYMBOL: current-clips
SINGLETON: +no-audio+

: with-current-clips ( quot -- )
    [ V{ } clone current-clips ] dip [
        +no-audio+ <clip> current-clips get push
    ] prepose with-variable ; inline

! PREDICATE: longlongattr < string 2 tail-slice* "ll" sequence= ;
! GENERIC: attr>number ( str -- number )
! M: longlongattr attr>number 2 head-slice* string>number ;

: current-audio ( -- audio )
    current-clips get last audio>> ;

: update-current-clip ( audio -- )
    current-audio 2dup =
    [ 2drop ]
    [ +no-audio+?
      [ current-clips get last audio<< ]
      [ ! f
          dup f =
          [ drop ]
          [ <clip> current-clips get push ] if
      ] if
    ] if ;

TAGS: change-clip ( elt -- )
TAG: stroke change-clip stroke-audio update-current-clip ;
TAG: image change-clip drop ;

: analyze-clips ( xml -- clips )
    [ pages [ layers [ strokes [
                           [ change-clip ] [ current-clips get last elements>> push ] bi
                       ] each ] each ] each
      current-clips get
    ] with-current-clips ;

TUPLE: clip-strokes-gadget < cairo-image-gadget strokes ;
: <clip-strokes-gadget> ( clip -- obj )
    clip-strokes-gadget new
    swap elements>> [ stroke-element? ] filter >>strokes ;

M: clip-strokes-gadget pref-dim*
    strokes>> strokes-dim ;

M: clip-strokes-gadget render-cairo* strokes>>
    [ [ strokes-rect loc>>
        cr swap first2 [ neg ] bi@ cairo_translate ]
    [ [ draw-stroke ] each ] bi ] with-saved-cairo-matrix ;

: <clip-gadget> ( clip -- )
    [ <clip-strokes-gadget> ] [  ]


! : ensure-clip ( -- )
!     current-clips get empty?
!     [ last-audio-file get <clip> current-clips get push ] when ;

! M: stroke change-clip  stroke-clip-info drop update-current-clip ;
! M: stroke change-clip audio>> update-current-clip ;
! M: image-elt change-clip drop ;
