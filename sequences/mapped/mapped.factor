USING: accessors kernel quotations sequences ;

IN: sequences.mapped
TUPLE: mapped
    { seq sequence read-only } ;

INSTANCE: mapped sequence
GENERIC: from* ( elt mapped -- elt )
M: mapped nth [ seq>> nth ] [ from* ] bi ; inline
M: mapped length seq>> length ; inline

TUPLE: quot-mapped < mapped { from callable read-only } ;
M: quot-mapped from* from>> call( x -- x ) ; inline

: <map> ( seq from: ( x -- x ) -- obj )
    quot-mapped boa ; inline
