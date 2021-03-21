(
    ( __import__ ( "forbiddenfruit" ) . curse ( tuple, "then", lambda a, f: f ( *a ) ), )
    . then ( lambda _: (
        __import__ ( "collections" ) . Counter,
        __import__ ( "operator" ) . eq,
        __import__ ( "sys" ) . modules,
    ) )
    . then ( lambda count, eq, mods: (
        lambda a, b: ( eq (
            count ( str.replace ( ( str.lower ( a ) ), " ", "" ) ),
            count ( str.replace ( ( str.lower ( b ) ), " ", "" ) ),
        ) ), )
        . then ( lambda entry: ( ( mods [ __name__ ] ), ) 
            . then ( lambda mod: ( ( setattr ( mod, "entry", entry ) ), ) ) )
    )
)