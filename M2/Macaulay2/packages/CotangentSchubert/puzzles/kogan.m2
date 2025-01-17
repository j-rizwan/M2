kogan = (d,sep,Ktheory,Ktheory',Generic,Equivariant) -> (
    if d>9 then error "this value of d not implemented"; -- arbitrary
    koganStates1 := {"_"} | apply(toList(0..d), toString); -- on slanted edges
    koganStates2 := apply(toList(0..d), toString)
    | flatten apply(toList(0..d), j->apply(toList(0..j-1),i->toString i | toString j)); -- on horiz edges

    rhombi := if Equivariant then if Generic then apply(koganStates1,i->{i,i,i,i}) else {{"_","_","_","_",equivstyle}} else {}; -- actually, Generic makes no diff because iiii never occurs for i!="_"
    if Generic then upTriangles := downTriangles := select(flatten table(koganStates1,koganStates1, (a,b) -> {a,b,if a=="_" then b else if b=="_" then a else concatenate sort {a,b}}), tri -> member(tri#2,koganStates2)) else (
	upTriangles = downTriangles = apply(toList(0..d),i->{"_",toString i,toString i})
	| apply(toList(0..d),i->{toString i,"_",toString i})
	| flatten apply(toList(0..d), j->apply(toList(0..j-1),i->{toString i,toString j,toString i | toString j}));
	if Ktheory then (
	    upTriangles = upTriangles | toList splice table(0..sep-1,sep..d,(i,j)->{toString j,toString i,toString i|toString j,Kstyle});
	    downTriangles = downTriangles | flatten apply(sep,j->apply(j,i->{toString j,toString i,toString i|toString j,Kstyle}))
	    | flatten apply(toList(sep..d),j->apply(toList(sep..j-1),i->{toString j,toString i,toString i|toString j,Kstyle}))
	    ) else if Ktheory' then (
	    downTriangles = downTriangles | toList splice table(0..sep-1,sep..d,(i,j)->{toString j,toString i,toString i|toString j,Kstyle});
	    upTriangles = upTriangles | flatten apply(sep,j->apply(j,i->{toString j,toString i,toString i|toString j,Kstyle}))
	    | flatten apply(toList(sep..d),j->apply(toList(sep..j-1),i->{toString j,toString i,toString i|toString j,Kstyle}))
	    );
	);
    (upTriangles,downTriangles,rhombi)
    )
