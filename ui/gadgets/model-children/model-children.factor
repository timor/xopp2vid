USING: accessors assocs kernel models namespaces sequences ui.gadgets ;

IN: ui.gadgets.model-children

! * Model-based gadget children
! Contract: model value must be a sequence of things which the class maps to
! gadget instances, which are cached based on grafting/ungrafting
MIXIN: model-children
GENERIC: child-model>gadget ( model gadget -- gadget )

! Called if a sequence of gadgets needs to be added to the parent gadget
GENERIC: add-model-children ( seq gadget -- gadget )
<PRIVATE
SYMBOL: gadget-cache
gadget-cache [ H{ } clone ] initialize

: init-cache ( gadget -- assoc )
    gadget-cache get [ drop H{ } clone ] cache ;

: cached-children ( seq gadget -- seq )
    [ init-cache ] keep
    '[ _ [ _ child-model>gadget ] cache ] map ;
PRIVATE>

: clear-gadget-cache ( gadget -- )
    gadget-cache get at clear-assoc ;

M: model-children ungraft*
    [ gadget-cache get delete-at ]
    [ call-next-method ] bi ;

M: model-children model-changed
    [ clear-gadget ]
    [ [ value>> ] dip cached-children ]
    [ add-model-children ] tri relayout ;
