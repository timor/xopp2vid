USING: accessors binary-search calendar combinators.short-circuit grouping
io.pathnames kernel locals math math.order namespaces sequences sequences.mapped
stroke-unit.clip-renderer stroke-unit.elements stroke-unit.strokes
stroke-unit.util xml.syntax ;

IN: stroke-unit.clips

TUPLE: clip ogg-file audio-path audio elements ;
: <clip> ( audio-path -- obj ) clip new swap >>audio-path V{ } clone >>elements ;

: <empty-clip> ( -- obj ) clip new ;

PREDICATE: empty-clip < clip elements>> empty? ;

SYMBOL: current-clips
SINGLETON: +no-audio+

: with-current-clips ( quot -- )
    [ V{ } clone current-clips ] dip [
        +no-audio+ <clip> current-clips get push
    ] prepose with-variable ; inline

: current-audio ( -- audio )
    current-clips get last audio-path>> ;

: update-current-clip ( audio -- )
    current-audio 2dup =
    [ 2drop ]
    [ +no-audio+?
      [ current-clips get last audio-path<< ]
      [ ! f
          dup f =
          [ drop ]
          [ <clip> current-clips get push ] if
      ] if
    ] if ;
SYMBOL: load-max-clip-size
load-max-clip-size [ 30 ] initialize

: limit-current-clip ( -- )
    current-clips get last elements>> length load-max-clip-size get >=
    [ +no-audio+ <clip> current-clips get push ] when ;

TAGS: change-clip ( elt -- )
TAG: stroke change-clip stroke-audio update-current-clip ;
TAG: image change-clip drop ;

: page-clips ( xml -- clips )
    [ layers [ strokes [
                   [ change-clip limit-current-clip ]
                   [ current-clips get last elements>> push ] bi
               ] each ] each
      current-clips get
    ] with-current-clips ;

! Adjusted for travel speed
: strokes-move-distance ( strokes -- l )
    [ [ stroke-segments ] map concat [ segment-length ] map-sum  ]
    [ dup length 1 >
      [ 2 <clumps> [ first2 inter-stroke-length travel-speed-factor get * ] map-sum ]
      [ drop 0 ] if
    ] bi + ;

: clip-move-distance ( clip -- pts )
    clip-strokes strokes-move-distance ;

: clip-video-duration ( clip -- duration )
    clip-move-distance stroke-speed get /f ;

! position is between 0.0 and 1.0
! TODO: candidate for caching if needed
! : clip-find-offset-stroke ( clip position -- stroke )
!     [ clip-strokes dup ] dip
!     over strokes-move-distance *
!     swap dup length <iota> [ 1 + head-slice strokes-move-distance ] with <map>
!     natural-search drop swap nth ;

:: clip-find-offset-stroke ( clip position -- stroke )
    clip clip-strokes :> strokes
    strokes strokes-move-distance position * :> target
    strokes length
    <iota> [ 1 + strokes swap head-slice strokes-move-distance target >= ] find
    [ strokes nth ] [ drop strokes last ] if ;
    ! [ [ f ] [ strokes nth ] if-zero ] [ drop f ] if*

    ! [ n ] [ drop strokes last ] if* ;

! * Splitting

: clear-clip-audio ( clip -- clip )
    f >>audio
    +no-audio+ >>audio-path ;

! Create new clips with subsets of elements before and after position
! audio removed for the second one
: clip-split-at ( clip position -- clip-before clip-after )
    [ clone dup ] dip clip-find-offset-stroke
    over elements>> [ index ] keep swap cut-slice
    [ >>elements ] [ [ dup clone ] dip >>elements clear-clip-audio ] bi* ;

! TODO: handle audio correctly
: clip-merge ( clip1 clip2 -- clip )
    swap clone [ swap elements>> append ] change-elements ;

! * Audio

: load-audio ( clip -- audio/f )
    dup audio>> [ nip ] [
        dup audio-path>> dup { [ +no-audio+? ] [ empty? ] } 1|| [ 2drop f ]
        [ get-current-audio-folder prepend-path ogg>audio
          >>audio audio>> ] if
    ] if* ;

: clip-audio-duration ( clip -- duration )
    load-audio [ audio-duration ] [ instant ] if* ;

: clip-duration ( clip -- duration )
    [ clip-video-duration ]
    [ clip-audio-duration ] bi max ;
