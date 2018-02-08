<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
    exclude-result-prefixes="tei" xmlns:tei="http://www.tei-c.org/ns/1.0">

    <!-- Performance: takes currently 1.5 to 2 seconds -->

    <xsl:output method="text" indent="no" encoding="UTF-8"/>
    
    <!-- match the master document that includes links to all transcriptions -->
    <xsl:template match="master">
        
        <!-- open JSON -->
        <xsl:text>{"witnesses": [&#xA;</xsl:text>

        <!-- STEP 1 - the transcription is transformed into xml structure similar to the future json format -->
        <xsl:variable name="xmlstage">

            <!-- each hand is a witness. -->
            <xsl:for-each select="descendant::tei:handNote">
                
                <!-- th variable vhand is the hand xml:id attribute, and will be passed as a parameter -->
                <!-- the reason is that both hand1 and hand2 are present in one manuscript, but must be treated as separate witnesses.
                    the hand parameter will allow to select additions and deletions from the hand that is currently tokenized. -->
                <xsl:variable name="vhand" select="@xml:id"/>
                
                <!-- each witness is defined by a siglum, a unique ID -->
                <!-- When there are more than one hand, add a number to the siglum (e.g. siglum="C1" and then "C2")
                    by creating a number that auto-increment with each hand, and concatenate it to the manuscript siglum found in msIdentifier.
                    If there is only one hand (for modern editor, for instance), 
                 -->
                
                <!-- handnb: number which will auto increment for each hand -->
                <xsl:variable name="handnb">
                    <xsl:number/>
                </xsl:variable>
                
                <!-- siglum: manuscript ID + hand number, or manuscript ID only -->
                <xsl:variable name="siglum">
                    <xsl:choose>
                        <!-- when there are more than one hand -->
                        <xsl:when test="parent::tei:handDesc/*[2]">
                            <!-- The value of siglum is ms ID + hand number -->
                            <xsl:value-of
                                select="concat(ancestor::tei:TEI/descendant::tei:msIdentifier/@xml:id, $handnb)"
                            />
                        </xsl:when>
                        <!-- otherwise, the value of siglum is ms ID only -->
                        <xsl:otherwise>
                            <xsl:value-of
                                select="ancestor::tei:TEI/descendant::tei:msIdentifier/@xml:id"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
                <!-- create a witness -->
                <witness id="{$siglum}">
                    
                    <!-- pass through each declamation -->
                    <xsl:for-each select="ancestor::tei:TEI/descendant::tei:ab">

                        <!--<declamation n="{@n}">-->
                        
                        <xsl:choose>
                            <!-- for modern editors, apply templates with mode 'edd' -->
                            <xsl:when test="$siglum = 'LH'">
                                <xsl:apply-templates mode="edd"/>
                            </xsl:when>
                            <!-- for manuscript witnesses and Pithoeus, apply templates with mode 'wit' -->
                            <xsl:otherwise>
                                <xsl:apply-templates mode="wit">
                                    <xsl:with-param name="phand" select="$vhand" tunnel="yes"/>
                                </xsl:apply-templates>
                            </xsl:otherwise>
                        </xsl:choose>

                        <!--</declamation>-->
                        
                    </xsl:for-each>
                </witness>
            </xsl:for-each>
        </xsl:variable>
        
        <!-- transform the XML stage into JSON format -->
        <xsl:apply-templates select="$xmlstage"/>

        <!-- close JSON -->
        <xsl:text>]&#xA;}</xsl:text>

    </xsl:template>

    <!-- **************************************************** -->
    <!-- *********** XMLSTAGE VARIABLE TEMPLATES ************ -->
    
    <xsl:template match="witness">
        <!-- Open JSON object for witness -->
        <xsl:text/>{&#xA;"id" : "<xsl:value-of select="@id"/>",&#xA;"tokens" : [&#xA;<xsl:text/>
        <!-- transform tokens into JSON -->
        <xsl:apply-templates/>
        <!-- close JSON witness -->
        <xsl:text>]&#xA;}</xsl:text>
        <!-- if it is not the last witness, add comma (following-sibling::witness)-->
        <xsl:if test="position() != last()"><xsl:text>,</xsl:text></xsl:if>
        <xsl:text>&#xA;</xsl:text>
    </xsl:template>

    <xsl:template match="token">
        <!-- %%%%%%%%% normalization of token %%%%%%%%% -->
        <xsl:variable name="norm">
            <xsl:choose>
                <xsl:when test="n"><xsl:value-of select="n"/></xsl:when>
                <xsl:when test="not(n)"><xsl:value-of select="t"/></xsl:when>
            </xsl:choose>
        </xsl:variable>
        <!-- replace &amp; by "et" -->
        <xsl:variable name="norm1" select="string(replace($norm, '&amp;', 'et'))"/>
        <!-- delete accents and 
             "double quotes" (if present) should be replaced by 'single quotes' (otherwise it creates JSON issues)-->
        <xsl:variable name="norm2"
            select="string(translate($norm1, 'àáèéêëîòóôùúû', 'aaeeeeiooouuu'))"/>
        <!-- delete crux and brackets <>[] (in Hakanson) -->
        <xsl:variable name="norm3" select="string(translate($norm2, '†\[\]&lt;&gt;', ''))"/>
        <!-- delete punctuation and any whitspaces -->
        <xsl:variable name="norm4"
            select="string(translate($norm3, '.,:;!?&quot;&#x20;()', ''))"/>
        <!-- lower case token -->
        <xsl:variable name="norm5" select="string(lower-case($norm4))"/>
        <!-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% -->
        
        <!-- creates JSON object for token -->
        
        <!-- t: original word -->
        <xsl:text/>&#x9;{"t" : "<xsl:value-of select="t"/>", <xsl:text/>
        
        <!-- n: normalized form (optional) -->
        <xsl:if test="$norm5 != t"><xsl:text/>"n" : "<xsl:value-of select="$norm5"/>",<xsl:text/></xsl:if>
        
        <!-- note: editorial note (optional) -->
        <xsl:if test="note"><xsl:text/>"note" : "<xsl:value-of select="note"/>",<xsl:text/></xsl:if>
        
        <!-- link: link to digital facismile (optional) -->
        <xsl:if test="link"><xsl:text/>"link" : "<xsl:value-of select="link"/>",<xsl:text/></xsl:if>
        
        <!-- decl: declamation number -->
        <xsl:text/>"decl" : "<xsl:value-of select="@decl"/>", <xsl:text/>
        
        <!-- locus: exact location in the witness, folio/page and line number -->
        <xsl:text/>"locus" : "<xsl:value-of select="@folio"/>:<xsl:value-of select="@line"/>"}<xsl:text/>
        
        <!-- if it is not the last token of the last declamation, add comma (following-sibling::token)-->
        <xsl:if test="position() != last()"><xsl:text>,</xsl:text></xsl:if>
        <xsl:text>&#xA;</xsl:text>
    </xsl:template>

    <xsl:template match="t"/>

    <xsl:template match="n"/>

    <xsl:template match="note"/>


    <!-- **************************************************** -->
    <!-- ************* TRANSCIRIPTION TEMPLATES ************* -->
    
    <xsl:template match="tei:w" mode="wit">
        <xsl:param name="phand" tunnel="yes"/>
        <token folio="{preceding::tei:pb[1]/@n}" line="{preceding::tei:lb[1]/@n}"
            decl="{ancestor::tei:ab/@n}">
            <xsl:choose>
                <!-- when there is a <choice> in <w>, the orig is part of token 't', while reg is part of normalized token 'n'.  -->
                <xsl:when test="descendant::tei:choice">
                    <t>
                        <!--apply all templates except reg -->
                        <xsl:apply-templates mode="attested">
                            <xsl:with-param name="phand"/>
                        </xsl:apply-templates>
                    </t>
                    <n>
                        <!--apply all templates except orig -->
                        <xsl:apply-templates mode="normal">
                            <xsl:with-param name="phand"/>
                        </xsl:apply-templates>
                    </n>
                </xsl:when>
                <!-- when there is no <choice>, just create a token 't'. -->
                <xsl:when test="not(descendant::tei:choice)">
                    <t>
                        <xsl:apply-templates mode="wit"/>
                    </t>
                </xsl:when>
            </xsl:choose>
            <!-- Notes material are found in several places
                -<note> element, but not of type=marginalia
                -attribute reason of <unclear> element
                -attribute resp of <reg> or <supplied> element
            -->
            <xsl:if test="(descendant::tei:note[not(@type = 'marginalia')] or descendant::tei:unclear/@reason) or(descendant::tei:reg/@resp or descendant::tei:supplied/@resp)">
                <note>
                    <xsl:value-of select="descendant::tei:note[not(@type = 'marginalia')]"/>
                    <xsl:value-of select="descendant::tei:unclear/@reason"/>
                    <xsl:if test="descendant::tei:reg/@resp">
                        <!-- ID of someone responsible of regularization form -->
                        <xsl:variable name="reference1" select="substring-after(descendant::tei:reg/@resp, '#')"/>
                        <!-- name of that person -->
                        <xsl:variable name="respName1"
                            select="ancestor::tei:TEI/descendant::tei:name[@xml:id=$reference1]"/>
                        <xsl:text/> Normalized form supplied by <xsl:value-of select="$respName1"/>.<xsl:text/>
                    </xsl:if> 
                    <xsl:if test="descendant::tei:supplied/@resp">
                        <!-- select name of resp with corresponding xml:id -->
                        <xsl:variable name="reference2" select="substring-after(descendant::tei:supplied/@resp, '#')"/>
                        <xsl:variable name="respName2"
                            select="ancestor::tei:TEI/descendant::tei:name[@xml:id=$reference2]"/>
                        <xsl:text/>
                        <!-- display of the note: text before or after the supplied letter(s) are represented with a dash -->
                        <xsl:if test="descendant::tei:supplied/preceding-sibling::node()[1][self::text()]">-</xsl:if>
                        <xsl:value-of select="descendant::tei:supplied"/>
                        <xsl:if test="descendant::tei:supplied/following-sibling::node()[1][self::text()]">-</xsl:if>
                        <xsl:text/> supplied by <xsl:value-of select="$respName2"/>.<xsl:text/>
                    </xsl:if>
                </note>
            </xsl:if>
            <!-- link to a digital image  -->
            <xsl:if test="preceding::tei:pb[1]/@facs">
                <link>
                    <xsl:value-of select="preceding::tei:pb[1]/@facs"/>
                </link>
            </xsl:if>
        </token>
    </xsl:template>
    
    <!-- sepcial segment for accurate transcription when there is an overlap issue with the XML encoding
        ignored. -->
    <xsl:template match="tei:seg[@type = 'transcription']" mode="#all"/>
    
    <!-- special segment for tokenization representation -->
    <xsl:template match="tei:seg[@type = 'tokenization']">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>

    <xsl:template match="tei:del" mode="wit attested normal">
        <xsl:param name="phand" tunnel="yes"/>
        <xsl:variable name="mss-hand">
            <xsl:choose>
                <!-- when there is no @hand attribute, 
                    the deleted text is written by h1 -->
                <xsl:when test="not(@hand)">h1</xsl:when>
                <!-- otherwise by h2 -->
                <xsl:otherwise>h2</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <!-- test if the hand who wrote the deleted text (mss-hand)
            is the hand that is tokenized (phand) -->
        <xsl:if test="$phand = $mss-hand">
            <xsl:apply-templates mode="#current"/>
        </xsl:if>
    </xsl:template>

    <xsl:template match="tei:del[@type = 'corrigendum']" mode="#all"/>

    <xsl:template match="tei:add" mode="wit normal attested">
        <xsl:param name="phand" tunnel="yes"/>
        <!-- test if the hand who wrote the addition is the hand that is toknized (phand) -->
        <xsl:if test="@hand = concat('#', $phand) or not(@hand)">
            <xsl:apply-templates mode="wit"/>
        </xsl:if>
    </xsl:template>

    <xsl:template match="text()" mode="#all">
        <!-- mode edd also -->
        <!-- deletes newlines, carriage returns and tabs -->
        <xsl:value-of select="translate(., '&#xA;|&#xD;|&#x9;', '')"/>
    </xsl:template>

    <xsl:template match="tei:choice/tei:orig" mode="wit normal"/>

    <xsl:template match="tei:choice/tei:orig" mode="wit attested">
        <xsl:param name="phand" tunnel="yes"/>
        <xsl:apply-templates mode="#current">
            <xsl:with-param name="phand"/>
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="tei:choice/tei:reg" mode="wit attested"/>

    <xsl:template match="tei:choice/tei:reg" mode="wit normal">
        <xsl:param name="phand" tunnel="yes"/>
        <xsl:apply-templates mode="#current">
            <xsl:with-param name="phand"/>
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="tei:g" mode="wit normal attested">
        <!--<xsl:text>ę</xsl:text>-->
        <xsl:variable name="reference" select="substring-after(current()/@ref, '#')"/>
        <xsl:variable name="glyph"
            select="ancestor::tei:TEI/descendant::tei:char[@xml:id = $reference]/tei:mapping[@type = 'diplomatic']"/>
        <xsl:value-of select="$glyph"/>
    </xsl:template>

    <xsl:template match="tei:ex" mode="wit normal attested">
        <xsl:apply-templates mode="#current"/>
        <!-- Abbreviations are not collated -->
        <!--<xsl:text>'</xsl:text>-->
    </xsl:template>

    <xsl:template match="tei:unclear" mode="wit normal attested">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>

    <xsl:template match="tei:hi" mode="wit normal attested">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>

    <xsl:template match="tei:pc" mode="wit normal attested"/>

    <xsl:template match="tei:note" mode=" wit normal attested"/>

    <xsl:template match="tei:num" mode="wit"/>

    <xsl:template match="tei:fw" mode="wit"/>

    <!-- This works because there is no gap or space inside a <w>. 
        Otherwise, xslt must be adapted to not create a token within another token! -->
    <xsl:template match="tei:gap" mode="edd wit">
        <token folio="{preceding::tei:pb[1]/@n}" line="{preceding::tei:lb[1]/@n}"
            decl="{ancestor::tei:ab/@n}">
            <!-- sth unique and not in the text of witnesses -->
            <t>...</t>
            <n>lacuna</n>
            <note>lacuna (gap) of <xsl:value-of select="@extent"/><xsl:text> </xsl:text><xsl:value-of select="@unit"/>.<xsl:if test="@reason"> Reason: <xsl:value-of select="@reason"/>.</xsl:if></note>
            <!-- link to a digital image  -->
            <xsl:if test="preceding::tei:pb[1]/@facs">
                <link>
                    <xsl:value-of select="preceding::tei:pb[1]/@facs"/>
                </link>
            </xsl:if>
        </token>
    </xsl:template>
    
    <xsl:template match="tei:space" mode="edd wit">
        <token folio="{preceding::tei:pb[1]/@n}" line="{preceding::tei:lb[1]/@n}"
            decl="{ancestor::tei:ab/@n}">
            <!-- sth unique and not in the text of witnesses -->
            <t>...</t>
            <n>lacuna</n>
            <note>lacuna (space) of <xsl:value-of select="@extent"/><xsl:text> </xsl:text><xsl:value-of select="@unit"/>.<xsl:value-of select="tei:desc"/></note>
            <!-- link to a digital image  -->
            <xsl:if test="preceding::tei:pb[1]/@facs">
                <link>
                    <xsl:value-of select="preceding::tei:pb[1]/@facs"/>
                </link>
            </xsl:if>
        </token>
    </xsl:template>

    <xsl:template match="tei:pb" mode="wit edd"/>
    <!-- mode edd -->

    <xsl:template match="tei:lb" mode="wit edd"/>
    <!-- mode edd -->

    <xsl:template match="tei:teiHeader" mode="wit edd"/>
    <!-- mode edd -->


    <!-- **************************************************** -->
    <!-- ********** MODERN EDITORS (EDD) TEMPLATES ********** -->
    
    <xsl:template match="tei:w" mode="edd">
        <token folio="{preceding::tei:pb[1]/@n}" line="{preceding::tei:lb[1]/@n}"
            decl="{ancestor::tei:ab/@n}">
            <t>
                <xsl:apply-templates mode="edd"/>
            </t>
            <!-- Final transcription of Hakanson has notes only in sic/@ana -->
            <xsl:if test="tei:unclear/@reason or tei:note or tei:sic/@ana">
                <note>
                    <xsl:value-of select="tei:unclear/@reason"/>
                    <xsl:value-of select="tei:sic/@ana"/>
                    <xsl:value-of select="tei:note"/>
                </note>
            </xsl:if>
            <!-- link to a digital text. For Hakanson, facs is related to each declamation not page (from the packhum website).  -->
            <xsl:if test="ancestor::tei:ab/@facs">
                <link><xsl:value-of select="ancestor::tei:ab/@facs"/></link>
            </xsl:if>
        </token>
    </xsl:template>

    <!-- For the moment: surplus do not appear in the collation 
        (because what the editor reads is an absence of the word. 
        They print it in [square barckets] only to show that the reading is present 
        in all manuscripts, but is not necessary. When displaying collation, 
        we could probably say that if all manuscript witnesses agree and edd is empty 
        => display reading in [] brackets. 
        
        Same for additions: if all manuscript witnesses are empty, 
        => display reading in <> brackets.
    -->

    <xsl:template match="tei:surplus" mode="edd"/>
    
    <xsl:template match="tei:supplied" mode="edd">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>

    <xsl:template match="tei:unclear" mode="edd">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>

    <xsl:template match="tei:pc" mode="edd"/>

</xsl:stylesheet>
