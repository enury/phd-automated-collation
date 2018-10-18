module transcription/collation		
open util/relation as relation
//-----------------------------------
//TYPE
sig Type {}		
//-----------------------------------
//TOKEN
sig Token {
	rtt: Reading->Type,
	d: one Document
	}{
	//changes to the initial readings model
	//to prevent tokens that are not mapped to a type
	//every token is a token in some reading of the document.
	some r : Reading | this in elems[r.tokenseq]
	
	//A token is in document D iff every reading that includes that token 
	//is a reading of document D.
	all r : Reading | this in elems[r.tokenseq] implies r.doc = d
	all r: Reading | this in elems [r.tokenseq] iff r.doc = d
	all r: Reading | all t: Type | r->t in rtt iff this->t in r.tt
}
//-----------------------------------
//DOCUMENT
sig Document {}	
//-----------------------------------
//READING
sig Reading {	
	//I added the "one"
	doc: one Document,
	tokenseq: seq Token,
	tt: Token->Type,
	//tt: Token->one Type //cf. Stackoverflow
	typeseq: seq Type
}{
	#tokenseq > 0
	not (hasDups [tokenseq])
	dom [tt] = elems [tokenseq]
	function [tt, elems [tokenseq]]
	typeseq = tokenseq.tt
}
//-----------------------------------
//TRANSCRIPTION
//similarity of 2 documents
pred t_similar (e, t: Document) {
	some r1, r2: Reading | 
	{r1.doc=e
	r2.doc=t
	r1.typeseq = r2.typeseq}
}
// similarity of 2 readings (added to the initial readings model)
pred r_similar (r1, r2: Reading) { 
	r1.typeseq = r2.typeseq
}
//-----------------------------------
//COLLATION
/*A very simplified model: we have 3 distinct documents.
* A base-text, an exemplar being collated against the base-text, and the collation.
* If the base-text and the exemplar share the same reading, then we do not collate.
* If the base-text and the exemplar have a different reading, then the exemplar's
* reading is transcribed
*
* So when do we have a situation of a reading being collated?
* (1) if a reading of the base-text and exemplar are different
* (2) then the readings of the exemplar and collation are the same
* (3) else nothing is transcribed in the collation document.
*/	
pred collation (disj b, e, c: Document) {
	some r1, r2, r3: Reading | 
	{
	//reading 1 is in the base text
	r1.doc=b
	
	//reading 2 is in the exemplar
	r2.doc=e
	
	//reading 3 is in transcribed in the collation iff r1 (base) and r2 (exemplar)
	//are different
	not r_similar[r1, r2] implies {r3.doc=c and r_similar[r2, r3] and t_similar[c, e]} 
	else no r: Reading | r.doc=c and  t_similar[b, e]
	}
}	
//-----------------------------------
//COMMAND
run collation 
