USING: accessors cairo-gadgets cairo.ffi formatting io.backend io.directories
io.launcher io.pathnames kernel make math math.functions namespaces sequences
stroke-unit.clip-renderer stroke-unit.clips stroke-unit.elements
stroke-unit.elements.images stroke-unit.models.clip-display stroke-unit.strokes
stroke-unit.util threads ;

IN: stroke-unit.page.renderer


! * Render clips to page frames, no translation

: render-frame-video ( fps in-pattern out-file -- )
    "ffmpeg -y -r %d -f image2 -i %s -vcodec mpeg2video -qscale 1 -qmin 1 -intra -an %s"
    sprintf try-process ;

: add-audio ( videofile audiofile outpath -- )
    [ normalize-path ] dip
    "ffmpeg -y -i %s -i %s -c:v libx264 -c:a aac -crf 20 -preset:v veryslow %s" sprintf try-process ;

TUPLE: render-pause pause ;
C: <render-pause> render-pause
TUPLE: speed-change speed ;
C: <speed-change> speed-change
SINGLETON: fresh-clip

TUPLE: render-entry elements audio ;
C: <render-entry> render-entry

:: make-render-list ( clip-displays -- seq )
    V{ } clone :> accum
    clip-displays [ dup :> display
                    [ clip>> ] [ stroke-speed!>> ] [ draw-duration>> ] tri :> ( clip speed duration )
                    clip audio-path>> +no-audio+ or :> this-audio
                    accum ?last [ audio>> ] [ this-audio ] if* :> last-audio
                    this-audio +no-audio+? not :> has-audio?
                    accum empty?
                    has-audio? last-audio this-audio = not and
                    or [ V{ } clone this-audio <render-entry> accum push ] when
                    fresh-clip accum last elements>> push
                    display no-draw-display?
                    [ duration <render-pause> accum last elements>> push ]
                    [ speed <speed-change> accum last elements>> push
                      clip elements>> accum last elements>> push-all
                    ] if
     ] each accum ;

! GENERIC: render-to-backend ( render-entry backend -- res )

! ! cr is bound during render-cairo-element
GENERIC: render-cairo-element ( surface element -- )
M: stroke render-cairo-element
    [ nip add-inter-stroke-pause ]
    [ swap render-stroke-frames ]
    [ nip last-stroke set ] 2tri ;

M: render-pause render-cairo-element
    pause>> fps get * round >integer
    swap [ add-frame ] curry times
    last-stroke off ;

M: speed-change render-cairo-element
    nip speed>> stroke-speed set ;

M: image-elt render-cairo-element
    nip render-cairo* ;

M: fresh-clip render-cairo-element
    2drop last-stroke off ;

! ! TUPLE: dummy-backend stats ;
! ! : <dummy-backend> ( -- obj ) V{ } clone dummy-backend boa ;

! ! GENERIC: render-dummy-element ( dummy-backend element -- )
! ! M: stroke render-dummy-element
! !     [ stats>> ] dip
! !     elements>>
! !     [ [ image-elt ] ]

! TUPLE: cairo-file-backend dim scale output-path clip-name index surface last-stroke ;
! C: cairo-file-backend <cairo-file-backend>
! GENERIC: fill-bg ( backend -- )
! GENERIC: finish-frame ( backend -- )

! : frame-path ( backend -- path )
!     [ output-path>> ] [ clip-name>> ] [ index>> ] tri
!     "%s-%05d.png" sprintf append-path ;

! M: cairo-file-backend fill-bg
!     [ dim>> ] [ surface>> ] bi
!     [ draw-white-bg ] with-cairo-from-surface ;

! M: cairo-file-backend finish-frame
!     [ frame-path>> ] [ surface>> ] bi
!     [ write-frame ] with-cairo-from-surface ;

! M:: cairo-file-backend render-to-backend ( entry backend -- res )
!     backend dim>> dup :> dim
!     [| surface |
!      cr backend scale>> dup cairo_scale
!     ] with-image-surface

! TODO: have separate cairo matrix for strokes, so that images can be scaled correctly...
:: render-page-clip-frames ( page dim clip-displays path -- frames )
    dim page page-dim fit-to-scale :> scale
    [ dim [| surface |
           cr scale dup cairo_scale
           dim draw-white-bg
           clip-displays make-render-list
           [| entry i |
            path i "clip-%02d" sprintf append-path normalize-path dup :> clip-dir
            frame-output-path set
            clip-dir make-directories
            0 path-suffix set
            0 segment-timer set
            last-stroke off
            surface add-frame
            entry elements>>
            [ surface swap render-cairo-element yield ] each
            fps get clip-dir "frame-%05d.png" append-path
            clip-dir ".mpg" append dup :> video-file render-frame-video
            entry audio>> dup +no-audio+?
            [ drop ]
            [ video-file swap clip-dir ".mp4" append add-audio ] if
           ] each-index
          ] with-image-surface
    ] { } make ;
