%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% -------------------------------------------------------------------------- %%
%% *** Modifed by Radim Loskot, xlosko01@stud.fit.vutbr.cz                *** %%
%% *** Modification takes charge only of these basic publication types:   *** %%
%% *** @Book, @InBook, @Proceedings, @InProceedings, @MastersThesis       *** %%
%% *** A new publication types were created: @OnlineWeb,@MediaProceedings,*** %%
%% ***                                       @InMediaProceedings          *** %%
%% *** Other publication types are unchanged and keeps rules from         *** %%
%% *** previous authors listed bellow                                     *** %%
%% *** Known issues: - warnings without booktitle in InProceedings        *** %%
%% ************************************************************************** %%
%%      SEZNAM ZMĚNĚNÝCH TYPŮ PUBLIKACÍ A VÝČET MOŽNÝCH POLOŽEK K CITACI      %%
%% ************************************************************************** %%
%% ----------------------------- MONOGRAFIE --------------------------------- %%                       
%% Type: @Book
%% Attributes: 
%% author. title : subtitle. editor, translator, illustrator, redactor, others. 
%% edition. address: publisher, year. pages. editiontitle, 
%% editionsubtitle, voledition. notes. url. ISBN, doi.
%%
%% ************************************************************************** %%
%% ---------------------- ČÁSTI MONOGRAFIÍ - KAPITOLY ----------------------- %%     
%% Type: @InBook
%% Attributes: 
%% author. title : subtitle. editor, translator, illustrator, redactor, others. 
%% edition. address: publisher, year. chapter, citpages. editiontitle, 
%% editionsubtitle, voledition. notes. url. isbn, doi.
%%
%% ************************************************************************** %%
%% ------------------------------- SERIÁLY ---------------------------------- %%                          
%% Type: @Proceedings                                                         
%% Attributes:
%% journaltitle : journalsubtitle. address: publisher, year. notes. url. issn, doi.
%%
%% ************************************************************************** %%
%% ------------------------ ČÁSTI SERIÁLŮ - ČLÁNKY -------------------------- %%
%% Type: @InProceedings
%% author. title : subtitle. translator, illustrator, others.
%% journaltitle : journalsubtitle. date/year, volume, number, citpages. notes. url. issn, doi.
%%
%% ************************************************************************** %%
%% ------------------------- KVALIFIKAČNÍ PRÁCE ----------------------------- %%
%% Type: @MastersThesis
%% author. title : subtitle (publishtype). address : publisher"school", 
%% year. pages, attachs. supervisor. notes. url. isbn, doi.
%%
%% ************************************************************************** %%
%% --------------------------- WEBOVÁ STRÁNKA ------------------------------- %%                   
%% Type: @OnlineWeb
%% Attributes: 
%% author. title : subtitle [online]. editor, translator, illustrator, redactor, others. 
%% edition. address: publisher, date/year, refresh [cited]. notes. citpages. 
%% postedition, postsubedition, voledition.  url. isbn, issn, doi.
%%
%% ************************************************************************** %%
%% ------------------------- ELEKTRONICKÝ SERIÁL ---------------------------- %%
%% Type: @MediaProceedings
%% Attributes: 
%% journaltitle : journalsubtitle [howpublished]. address: publisher, year [cited]. 
%% notes. url. issn, doi.
%%
%% ************************************************************************** %%
%% -------------------------- ELEKTRONICKÝ ČLÁNEK --------------------------- %%              
%% Type: @InMediaProceedings
%% Attributes: 
%% author. title : subtitle. translator, illustrator, others.
%% journaltitle : journalsubtitle [howpublished]. date/year, volume, number, 
%% refresh [cited]. citpages. notes. url. issn, doi.
%% -----------------------------------------------------------------------------
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% This is file `czechiso.bst',
%% generated with the docstrip utility.
%%
%% The original source files were:
%%
%% merlin.mbs  (with options: `head,exlang,lang,vonx,nm-rev,jnrlst,aunm-semi,nmlm,x3,m3,atit-u,vnum-nr,volp-sp,jwdpg,pp-last,jwdvol,num-xser,ser-vol,ser-ed,pg-bk,add-pub,isbn,issn,doi,edpar,edby,blk-tit,au-col,čeština,pp,and-xcom,xand,eprint,url,url-nl,nfss,,{}')
%% czech.mbs  (with options: `exlang,lang,vonx,nm-rev,jnrlst,aunm-semi,nmlm,x3,m3,atit-u,vnum-nr,volp-sp,jwdpg,pp-last,jwdvol,num-xser,ser-vol,ser-ed,pg-bk,add-pub,isbn,issn,doi,edpar,edby,blk-tit,au-col,čeština,pp,and-xcom,xand,eprint,url,url-nl,nfss,,{}')
%% merlin.mbs  (with options: `tail,exlang,lang,vonx,nm-rev,jnrlst,aunm-semi,nmlm,x3,m3,atit-u,vnum-nr,volp-sp,jwdpg,pp-last,jwdvol,num-xser,ser-vol,ser-ed,pg-bk,add-pub,isbn,issn,doi,edpar,edby,blk-tit,au-col,čeština,pp,and-xcom,xand,eprint,url,url-nl,nfss,,{}')
%% ----------------------------------------
%% *** Styl snažící se být v souladu s normou ISO 690. Pomocí latex makebst vytvořil David Martinek. ***
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Copyright 1994-2004 Patrick W Daly
 % ===============================================================
 % IMPORTANT NOTICE:
 % This bibliographic style (bst) file has been generated from one or
 % more master bibliographic style (mbs) files, listed above.
 %
 % This generated file can be redistributed and/or modified under the terms
 % of the LaTeX Project Public License Distributed from CTAN
 % archives in directory macros/latex/base/lppl.txt; either
 % version 1 of the License, or any later version.
 % ===============================================================
 % Name and version information of the main mbs file:
 % \ProvidesFile{merlin.mbs}[2004/02/09 4.13 (PWD, AO, DPC)]
 %   For use with BibTeX version 0.99a or later
 %-------------------------------------------------------------------
 % This bibliography style file is intended for texts in
 % This is a numerical citation style, and as such is standard LaTeX.
 % It requires no extra package to interface to the main text.
 % The form of the \bibitem entries is
 %   \bibitem{key}...
 % Usage of \cite is as follows:
 %   \cite{key} ==>>          [#]
 %   \cite[chap. 2]{key} ==>> [#, chap. 2]
 % where # is a number determined by the ordering in the reference list.
 % The order in the reference list is alphabetical by authors.
 %---------------------------------------------------------------------


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                 VYSVĚTLENÍ MNOU POUŽÍVANÝCH CITAČNÍCH POLOŽEK              %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ENTRY
  { address             %% Místo-město vydání        % Brno nebo Praha 
    attachs             %% Počet/typ příloh          % 2 CD, mapa nebo 2 grafy
    cited               %% Datum citace              % 2008-02-01 nebo 22.1.2009  
    archive
    author              %% Autoři         % Jmeno1 PRIJMENI1 and Jmeno2 Primeni2
    booktitle
    chapter             %% Název kapitoly       
    citpages            %% Citované stránka(y)          % 10-25 nebo 10 
    doi                 %% Jiné ID knížky               % je třeba zapsat celé
    edition             %% Číslo vydání                 % 3. vyd. nebo 3rd ed.
    editiontitle        %% Nýzev edice
    editionsubtitle     %% Podnázev edice
    editor              %% Editor
    eid
    eprint
    howpublished        %% Typ publikování               % CD-ROM nebo online
    illustrator         %% Ilustrátor
    institution
    isbn                %% Book number
    issn                %% Serial number
    journal
    journaltitle        %% Název deníku/časopisu/svazku       
    journalsubtitle     %% Podnázev deníku/časopisu 
    key                 %% Doplňující klíč řazení
    language
    month
    note                
    notes               %% Poznámky
    number              %% Číslo časopisu    
    organization
    others              %% Další lidé podílející se na vydání
    pages               %% Počet stránek - udává se pouze číslo
    publisher           %% Nakladatelství
    publishtype         %% Typ publikace (diplomka/bakalářka atd.)
    redactor            %% Redactor
    refresh
    series
    supervisor          %% Vedoucí práce
    title               %% Titul knížky
    translator          %% Překladatel
    subtitle            %% Podtitul knížky
    type
    url                 %% Dostupný na url
    voledition          %% Číslo svazku edice
    volume              %% Svazek
    year                %% Rok vydání
  }
  {}
  { label }
INTEGERS { output.state before.all mid.sentence after.sentence after.block }
FUNCTION {init.state.consts}
{ #0 'before.all :=
  #1 'mid.sentence :=
  #2 'after.sentence :=
  #3 'after.block :=
}
STRINGS { s t}
FUNCTION {output.nonnull}
{ 's :=
  output.state mid.sentence =
    { ", " * write$ }
    { output.state after.block =
        { add.period$ write$
          newline$
          "\newblock " write$
        }
        { output.state before.all =
            'write$
            { add.period$ " " * write$ }
          if$
        }
      if$
      mid.sentence 'output.state :=
    }
  if$
  s
}
FUNCTION {output}
{ duplicate$ empty$
    'pop$
    'output.nonnull
  if$
}
FUNCTION {output.check}
{ 't :=
  duplicate$ empty$
    { pop$ "empty " t * " in " * cite$ * warning$ }
    'output.nonnull
  if$
}
FUNCTION {fin.entry}
{ add.period$
  write$
  newline$
}

FUNCTION {new.block}
{ output.state before.all =
    'skip$
    { after.block 'output.state := }
  if$
}
FUNCTION {new.sentence}
{ output.state after.block =
    'skip$
    { output.state before.all =
        'skip$
        { after.sentence 'output.state := }
      if$
    }
  if$
}
FUNCTION {add.blank}
{  " " * before.all 'output.state :=
}

FUNCTION {add.colon}
{ duplicate$ empty$
    'skip$
    { add.blank ":" * add.blank }
  if$
}

FUNCTION {date.block}
{
  skip$
}

FUNCTION {not}
{   { #0 }
    { #1 }
  if$
}
FUNCTION {and}
{   'skip$
    { pop$ #0 }
  if$
}
FUNCTION {or}
{   { pop$ #1 }
    'skip$
  if$
}
FUNCTION {new.block.checka}
{ empty$
    'skip$
    'new.block
  if$
}
FUNCTION {new.block.checkb}
{ empty$
  swap$ empty$
  and
    'skip$
    'new.block
  if$
}
FUNCTION {new.sentence.checka}
{ empty$
    'skip$
    'new.sentence
  if$
}
FUNCTION {new.sentence.checkb}
{ empty$
  swap$ empty$
  and
    'skip$
    'new.sentence
  if$
}
FUNCTION {field.or.null}
{ duplicate$ empty$
    { pop$ "" }
    'skip$
  if$
}
FUNCTION {emphasize}
{ duplicate$ empty$
    { pop$ "" }
    { "\emph{" swap$ * "}" * }
  if$
}
FUNCTION {tie.or.space.prefix}
{ duplicate$ text.length$ #3 <
    { "~" }
    { " " }
  if$
  swap$
}

FUNCTION {capitalize}
{ "u" change.case$ "t" change.case$ }

FUNCTION {space.word}
{ " " swap$ * " " * }
 % Here are the language-specific definitions for explicit words.
 % Each function has a name bbl.xxx where xxx is the English word.
 %-------------------------------------------------------------------
 % Begin module:
 % \ProvidesFile{czech.mbs}[2006/03/31 1.0 (DM)]

 % The language selected here is CZECH
FUNCTION {bbl.and}
{ "a"}

FUNCTION {bbl.etal}
{ "aj." }

FUNCTION {bbl.editors}
{ "editoři" }

FUNCTION {bbl.editor}
{ "editor" }

FUNCTION {bbl.edby}
{ "editace" }

FUNCTION {bbl.edition}
{ "vyd" }

FUNCTION {bbl.volume}
{ "roč." }

FUNCTION {bbl.of}
{ "" }

FUNCTION {bbl.number}
{ "číslo" }

FUNCTION {bbl.nr}
{ "č." }

FUNCTION {bbl.in}
{ "in" }

FUNCTION {bbl.pages}
{ "s" }

FUNCTION {bbl.page}
{ "str." }

FUNCTION {bbl.chapter}
{ "kapitola" }

FUNCTION {bbl.techrep}
{ "Technická Zpráva" }

FUNCTION {bbl.mthesis}
{ "Diplomová práce" }

FUNCTION {bbl.phdthesis}
{ "Dizertační práce" }

FUNCTION {bbl.first}
{ "První" }

FUNCTION {bbl.second}
{ "Druhé" }

FUNCTION {bbl.third}
{ "Třetí" }

FUNCTION {bbl.fourth}
{ "Čtvrté" }

FUNCTION {bbl.fifth}
{ "Páté" }

FUNCTION {bbl.st}
{ "" }

FUNCTION {bbl.nd}
{ "" }

FUNCTION {bbl.rd}
{ "" }

FUNCTION {bbl.th}
{ "" }

MACRO {jan} {"Leden"}

MACRO {feb} {"Únor"}

MACRO {mar} {"Březen"}

MACRO {apr} {"Duben"}

MACRO {may} {"Květen"}

MACRO {jun} {"Červen"}

MACRO {jul} {"Červenec"}

MACRO {aug} {"Srpen"}

MACRO {sep} {"Září"}

MACRO {oct} {"Říjen"}

MACRO {nov} {"Listopad"}

MACRO {dec} {"Prosinec"}

 % End module: czech.mbs
%% Copyright 1994-2004 Patrick W Daly
MACRO {acmcs} {"ACM Computing Surveys"}

MACRO {acta} {"Acta Informatica"}

MACRO {cacm} {"Communications of the ACM"}

MACRO {ibmjrd} {"IBM Journal of Research and Development"}

MACRO {ibmsj} {"IBM Systems Journal"}

MACRO {ieeese} {"IEEE Transactions on Software Engineering"}

MACRO {ieeetc} {"IEEE Transactions on Computers"}

MACRO {ieeetcad}
 {"IEEE Transactions on Computer-Aided Design of Integrated Circuits"}

MACRO {ipl} {"Information Processing Letters"}

MACRO {jacm} {"Journal of the ACM"}

MACRO {jcss} {"Journal of Computer and System Sciences"}

MACRO {scp} {"Science of Computer Programming"}

MACRO {sicomp} {"SIAM Journal on Computing"}

MACRO {tocs} {"ACM Transactions on Computer Systems"}

MACRO {tods} {"ACM Transactions on Database Systems"}

MACRO {tog} {"ACM Transactions on Graphics"}

MACRO {toms} {"ACM Transactions on Mathematical Software"}

MACRO {toois} {"ACM Transactions on Office Information Systems"}

MACRO {toplas} {"ACM Transactions on Programming Languages and Systems"}

MACRO {tcs} {"Theoretical Computer Science"}
FUNCTION {bibinfo.check}
{ swap$
  duplicate$ missing$
    {
      pop$ pop$
      ""
    }
    { duplicate$ empty$
        {
          swap$ pop$
        }
        { swap$
          pop$
        }
      if$
    }
  if$
}
FUNCTION {bibinfo.warn}
{ swap$
  duplicate$ missing$
    {
      swap$ "missing " swap$ * " in " * cite$ * warning$ pop$
      ""
    }
    { duplicate$ empty$
        {
          swap$ "empty " swap$ * " in " * cite$ * warning$
        }
        { swap$
          pop$
        }
      if$
    }
  if$
}
FUNCTION {format.eprint}
{ eprint duplicate$ empty$
    'skip$
    { "\eprint"
      archive empty$
        'skip$
        { "[" * archive * "]" * }
      if$
      "{" * swap$ * "}" *
    }
  if$
}
FUNCTION {write.url}
{ url empty$
    { skip$ }
    { "\urlprefix\url{" url * "}\urlsuffix" * write$ newline$ }
  if$
}

STRINGS  { bibinfo}
INTEGERS { nameptr namesleft numnames }

FUNCTION {format.names}
{ 'bibinfo :=
  duplicate$ empty$ 'skip$ {
  's :=
  "" 't :=
  #1 'nameptr :=
  s num.names$ 'numnames :=
  numnames 'namesleft :=
    { namesleft #0 > }
    { s nameptr
      "{vv~}{ll}{, f.}{, jj}"
      format.name$
      bibinfo bibinfo.check
      't :=
      nameptr #1 >
        {
          nameptr #3
          #1 + =
          numnames #3
          > and
            { "others" 't :=
              #1 'namesleft := }
            'skip$
          if$
          namesleft #1 >
            { "; " * t * }
            {
              ";" *
              s nameptr "{ll}" format.name$ duplicate$ "others" =
                { 't := }
                { pop$ }
              if$
              t "others" =
                {
                  " " * bbl.etal *
                }
                { " " * t * }
              if$
            }
          if$
        }
        't
      if$
      nameptr #1 + 'nameptr :=
      namesleft #1 - 'namesleft :=
    }
  while$
  } if$
}
FUNCTION {format.names.ed}
{
  'bibinfo :=
  duplicate$ empty$ 'skip$ {
  's :=
  "" 't :=
  #1 'nameptr :=
  s num.names$ 'numnames :=
  numnames 'namesleft :=
    { namesleft #0 > }
    { s nameptr
      "{f.~}{vv~}{ll}{, jj}"
      format.name$
      bibinfo bibinfo.check
      't :=
      nameptr #1 >
        {
          namesleft #1 >
            { "; " * t * }
            {
              ";" *
              s nameptr "{ll}" format.name$ duplicate$ "others" =
                { 't := }
                { pop$ }
              if$
              t "others" =
                {

                  " " * bbl.etal *
                }
                { " " * t * }
              if$
            }
          if$
        }
        't
      if$
      nameptr #1 + 'nameptr :=
      namesleft #1 - 'namesleft :=
    }
  while$
  } if$
}
FUNCTION {format.authors}
{ author "author" format.names
}
FUNCTION {get.bbl.editor}
{ editor num.names$ #1 > 'bbl.editors 'bbl.editor if$ }

FUNCTION {format.editors}
{ editor "editor" format.names duplicate$ empty$ 'skip$
    {
      " " *
      get.bbl.editor
   "(" swap$ * ")" *
      *
    }
  if$
}
FUNCTION {format.book.pages}
{ pages "pages" bibinfo.check
  duplicate$ empty$ 'skip$
    { "~" * bbl.pages * }
  if$
}
FUNCTION {format.isbn}
{ isbn "isbn" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "ISBN~" swap$ *
    }
  if$
}

FUNCTION {format.issn}
{ issn "issn" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "ISSN " swap$ *
    }
  if$
}

FUNCTION {format.doi}
{ doi "doi" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "" swap$ * "" *
    }
  if$
}
FUNCTION {select.language}
{ duplicate$ empty$
    'pop$
    { language empty$
        'skip$
        { "{\selectlanguage{" language * "}" * swap$ * "}" * }
      if$
    }
    if$
}

FUNCTION {format.note}
{
 note empty$
    { "" }
    { note #1 #1 substring$
      duplicate$ "{" =
        'skip$
        { output.state mid.sentence =
          { "l" }
          { "u" }
        if$
        change.case$
        }
      if$
      note #2 global.max$ substring$ * "note" bibinfo.check
    }
  if$
}

FUNCTION {format.title}
{ title
  "title" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      select.language
    }
  if$
}
FUNCTION {output.bibitem}
{ newline$
  "\bibitem{" write$
  cite$ write$
  "}" write$
  newline$
  ""
  before.all 'output.state :=
}

FUNCTION {n.dashify}
{
  't :=
  ""
    { t empty$ not }
    { t #1 #1 substring$ "-" =
        { t #1 #2 substring$ "--" = not
            { "--" *
              t #2 global.max$ substring$ 't :=
            }
            {   { t #1 #1 substring$ "-" = }
                { "-" *
                  t #2 global.max$ substring$ 't :=
                }
              while$
            }
          if$
        }
        { t #1 #1 substring$ *
          t #2 global.max$ substring$ 't :=
        }
      if$
    }
  while$
}

FUNCTION {word.in}
{ bbl.in capitalize
  " " * }

FUNCTION {format.date}
{
  month "month" bibinfo.check
  duplicate$ empty$
  year  "year"  bibinfo.check duplicate$ empty$
    { swap$ 'skip$
        { "there's a month but no year in " cite$ * warning$ }
      if$
      *
    }
    { swap$ 'skip$
        {
          swap$
          " " * swap$
        }
      if$
      *
    }
  if$
}
FUNCTION {format.btitle}
{ title "title" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      emphasize
      select.language
    }
  if$
}
FUNCTION {either.or.check}
{ empty$
    'pop$
    { "can't use both " swap$ * " fields in " * cite$ * warning$ }
  if$
}
FUNCTION {format.bvolume}
{ volume empty$
    { "" }
    { bbl.volume volume tie.or.space.prefix
      "volume" bibinfo.check * *
      series "series" bibinfo.check
      duplicate$ empty$ 'pop$
        { emphasize ", " * swap$ * }
      if$
      "volume and number" number either.or.check
    }
  if$
}
FUNCTION {format.number.series}
{ volume empty$
    { number empty$
        { series field.or.null }
        { series empty$
            { number "number" bibinfo.check }
            { output.state mid.sentence =
                { bbl.number }
                { bbl.number capitalize }
              if$
              number tie.or.space.prefix "number" bibinfo.check * *
              bbl.in space.word *
              series "series" bibinfo.check *
            }
          if$
        }
      if$
    }
    { "" }
  if$
}
FUNCTION {is.num}
{ chr.to.int$
  duplicate$ "0" chr.to.int$ < not
  swap$ "9" chr.to.int$ > not and
}

FUNCTION {extract.num}
{ duplicate$ 't :=
  "" 's :=
  { t empty$ not }
  { t #1 #1 substring$
    t #2 global.max$ substring$ 't :=
    duplicate$ is.num
      { s swap$ * 's := }
      { pop$ "" 't := }
    if$
  }
  while$
  s empty$
    'skip$
    { pop$ s }
  if$
}

FUNCTION {format.subtitle}
{ 
  
  subtitle "subtitle" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "\emph{" add.colon swap$ * "}" *
    }
  if$
}

FUNCTION {format.onlinesubtitle}
{ 
  subtitle empty$
  { add.blank " [online]." }
  {    
  subtitle "subtitle" bibinfo.check
  duplicate$ empty$ 'skip$ 
    {
      "\emph{" add.colon swap$ * "} [online]." *
    }
  if$
  }
  if$ 
}

FUNCTION {format.redactor}
{     
  redactor "redactor" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "" swap$ *
    }
  if$
}

FUNCTION {format.illustrator}
{   
  illustrator "illustrator" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "" swap$ *
    }
  if$
}

FUNCTION {format.translator}
{ 
  translator "translator" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "" swap$ *
    }
  if$
}

FUNCTION {format.others}
{ 
  others "others" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "" swap$ *
    }
  if$
}

FUNCTION {format.editiontitle}
{ 
  editiontitle "editiontitle" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "" swap$ *
    }
  if$
}

FUNCTION {format.editionsubtitle}
{ 
  editionsubtitle "editionsubtitle" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "" swap$ *
    }
  if$
}

FUNCTION {format.voledition}
{ 
  voledition "voledition" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "" swap$ *
    }
  if$
}

FUNCTION {format.notes}
{ 
  notes "notes" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "" swap$ *
    }
  if$
  new.sentence
}

FUNCTION {format.url}
{ 
  url "url" bibinfo.check
  duplicate$ empty$ 'skip$
    {                     
      "\urlprefix\url{" swap$ * "}\urlsuffix" *
    }
  if$
}

FUNCTION {format.editor}
{ 
  editor "editor" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "" swap$ * 
    }
  if$
}

FUNCTION {format.chapter}
{ 
  chapter "chapter" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "" swap$ * 
    }
  if$
}

FUNCTION {format.citpages}
{ 
  citpages "citpages" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "s.~" swap$ * 
    }
  if$
}

FUNCTION {format.journaltitle}
{ 
  journaltitle "journaltitle" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "\emph{" swap$ * "}" *
    }
  if$
}

FUNCTION {format.journalsubtitle}
{ 
  journalsubtitle "journalsubtitle" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "\emph{" add.colon swap$ * "}" *
    }
  if$
}

FUNCTION {format.volume}
{ 
  volume "volume" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "" swap$ * 
    }
  if$
}

FUNCTION {format.number}
{ 
  number "number" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "" swap$ * 
    }
  if$
}

FUNCTION {format.titlenorm}
{ 
  title "titlenorm" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "" swap$ * 
    }
  if$
}

FUNCTION {format.subtitlenorm}
{ 
  
  subtitle "subtitlenorm" bibinfo.check
  duplicate$ empty$ 'skip$
    {   
      " : " add.blank swap$ *
    }
  if$
}

FUNCTION {format.publishtype}
{ 
  add.blank
  publishtype "publishtype" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      " (" swap$ * ")" *
    }
  if$
}

FUNCTION {format.attachs}
{ 
  attachs "attachs" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "" swap$ * 
    }
  if$
}

FUNCTION {format.supervisor}
{ 
  supervisor "supervisor" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "Vedoucí práce " swap$ * 
    }
  if$
}

FUNCTION {format.refresh}
{ 
  refresh "refresh" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      "" swap$ * 
    }
  if$
}

FUNCTION {format.cited}
{ 
  add.blank
  cited "cited" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      " [cit. " swap$ * "]" * 
    }
  if$
}

FUNCTION {format.howpublished}
{ 
  add.blank
  howpublished "howpublished" bibinfo.check
  duplicate$ empty$ 'skip$
    {
      " [" swap$ * "]." * 
    }
  if$
}      

FUNCTION {format.edition}
{ edition duplicate$ empty$ 'skip$
    {
      output.state mid.sentence =
        { "l" }
        { "t" }
      if$ change.case$
      "edition" bibinfo.check
      
    }
  if$
}
INTEGERS { multiresult }
FUNCTION {multi.page.check}
{ 't :=
  #0 'multiresult :=
    { multiresult not
      t empty$ not
      and
    }
    { t #1 #1 substring$
      duplicate$ "-" =
      swap$ duplicate$ "," =
      swap$ "+" =
      or or
        { #1 'multiresult := }
        { t #2 global.max$ substring$ 't := }
      if$
    }
  while$
  multiresult
}
FUNCTION {format.pages}
{ pages duplicate$ empty$ 'skip$
    { duplicate$ multi.page.check
        {
          bbl.pages swap$
          n.dashify
        }
        {
          bbl.page swap$
        }
      if$
      tie.or.space.prefix
      "pages" bibinfo.check
      * *
    }
  if$
}
FUNCTION {format.journal.pages}
{ pages duplicate$ empty$ 'pop$
    { swap$ duplicate$ empty$
        { pop$ pop$ format.pages }
        {
          ": " *
          swap$
          n.dashify
          pages multi.page.check
            'bbl.pages
            'bbl.page
          if$
          swap$ tie.or.space.prefix
          "pages" bibinfo.check
          * *
          *
        }
      if$
    }
  if$
}
FUNCTION {format.journal.eid}
{ eid "eid" bibinfo.check
  duplicate$ empty$ 'pop$
    { swap$ duplicate$ empty$ 'skip$
      {
          ": " *
      }
      if$
      swap$ *
    }
  if$
}
FUNCTION {format.vol.num.pages}
{ volume field.or.null
  duplicate$ empty$ 'skip$
    {
      bbl.volume swap$ tie.or.space.prefix
      "volume" bibinfo.check
      * *
    }
  if$
  number "number" bibinfo.check duplicate$ empty$ 'skip$
    {
      swap$ duplicate$ empty$
        { "there's a number but no volume in " cite$ * warning$ }
        'skip$
      if$
      swap$
      ", " bbl.nr * number tie.or.space.prefix pop$ * swap$ *
    }
  if$ *
}

FUNCTION {format.chapter.pages}
{ chapter empty$
    { "" }
    { type empty$
        { bbl.chapter }
        { type "l" change.case$
          "type" bibinfo.check
        }
      if$
      chapter tie.or.space.prefix
      "chapter" bibinfo.check
      * *
    }
  if$
}

FUNCTION {format.booktitle}
{
  booktitle "booktitle" bibinfo.check
  emphasize
}
FUNCTION {format.in.ed.booktitle}
{ format.booktitle duplicate$ empty$ 'skip$
    {
      format.bvolume duplicate$ empty$ 'pop$
        { ", " swap$ * * }
      if$
      editor "editor" format.names.ed duplicate$ empty$ 'pop$
        {
          bbl.edby
          " " * swap$ *
          swap$
          "," *
          " " * swap$
          * }
      if$
      word.in swap$ *
    }
  if$
}
FUNCTION {empty.misc.check}
{ author empty$ title empty$ howpublished empty$
  month empty$ year empty$ note empty$
  and and and and and
  key empty$ not and
    { "all relevant fields are empty in " cite$ * warning$ }
    'skip$
  if$
}
FUNCTION {format.thesis.type}
{ type duplicate$ empty$
    'pop$
    { swap$ pop$
      "t" change.case$ "type" bibinfo.check
    }
  if$
}
FUNCTION {format.tr.number}
{ number "number" bibinfo.check
  type duplicate$ empty$
    { pop$ bbl.techrep }
    'skip$
  if$
  "type" bibinfo.check
  swap$ duplicate$ empty$
    { pop$ "t" change.case$ }
    { tie.or.space.prefix * * }
  if$
}
FUNCTION {format.article.crossref}
{
  key duplicate$ empty$
    { pop$
      journal duplicate$ empty$
        { "need key or journal for " cite$ * " to crossref " * crossref * warning$ }
        { "journal" bibinfo.check emphasize word.in swap$ * }
      if$
    }
    { word.in swap$ * " " *}
  if$
  " \cite{" * crossref * "}" *
}
FUNCTION {format.crossref.editor}
{ editor #1 "{vv~}{ll}" format.name$
  "editor" bibinfo.check
  editor num.names$ duplicate$
  #2 >
    { pop$
      "editor" bibinfo.check
      " " * bbl.etal
      *
    }
    { #2 <
        'skip$
        { editor #2 "{ff }{vv }{ll}{ jj}" format.name$ "others" =
            {
              "editor" bibinfo.check
              " " * bbl.etal
              *
            }
            {
             bbl.and space.word
              * editor #2 "{vv~}{ll}" format.name$
              "editor" bibinfo.check
              *
            }
          if$
        }
      if$
    }
  if$
}
FUNCTION {format.book.crossref}
{ volume duplicate$ empty$
    { "empty volume in " cite$ * "'s crossref of " * crossref * warning$
      pop$ word.in
    }
    { bbl.volume
      capitalize
      swap$ tie.or.space.prefix "volume" bibinfo.check * * bbl.of space.word *
    }
  if$
  editor empty$
  editor field.or.null author field.or.null =
  or
    { key empty$
        { series empty$
            { "need editor, key, or series for " cite$ * " to crossref " *
              crossref * warning$
              "" *
            }
            { series emphasize * }
          if$
        }
        { key * }
      if$
    }
    { format.crossref.editor * }
  if$
  " \cite{" * crossref * "}" *
}
FUNCTION {format.incoll.inproc.crossref}
{
  editor empty$
  editor field.or.null author field.or.null =
  or
    { key empty$
        { format.booktitle duplicate$ empty$
            { "need editor, key, or booktitle for " cite$ * " to crossref " *
              crossref * warning$
            }
            { word.in swap$ * }
          if$
        }
        { word.in key * " " *}
      if$
    }
    { word.in format.crossref.editor * " " *}
  if$
  " \cite{" * crossref * "}" *
}
FUNCTION {format.org.or.pub}
{ 't :=
  ""
  address empty$ t empty$ and
    'skip$
    {
      address "address" bibinfo.check *
      t empty$
        'skip$
        { address empty$
            'skip$
            { ": " * }
          if$
          t *
        }
      if$
    }
  if$
}
FUNCTION {format.publisher.address}
{ publisher "publisher" bibinfo.warn format.org.or.pub
}

FUNCTION {format.organization.address}
{ organization "organization" bibinfo.check format.org.or.pub
}

FUNCTION {article}
{ output.bibitem
  format.authors "author" output.check
  add.colon
  format.title "title" output.check
  new.sentence
  crossref missing$
    {
      journal
      "journal" bibinfo.check
      emphasize
      "journal" output.check
      format.vol.num.pages output
      format.date "year" output.check
    }
    { format.article.crossref output.nonnull
    }
  if$
  eid empty$
    { format.journal.pages }
    { format.journal.eid }
  if$
  format.issn output
  format.doi output
  format.note output
  format.eprint output
  fin.entry
  write.url
}

%%%%%%%%%%%%%%%%%%%%%%%%%%% BLOCK OF EDITED STYLES %%$$$$$$$$$$$%%%%%%%%%$$$$$$$

FUNCTION {book}                                                    %% MONOGRAFIE
{ output.bibitem
  format.authors output
  new.sentence   
  format.btitle "title" output.check
  format.subtitle output
  new.sentence
  format.editor output 
  format.translator output
  format.illustrator output
  format.redactor output
  format.others output
  new.sentence
  format.edition output
  new.sentence
  crossref missing$
    { format.bvolume output
      format.number.series output
      format.publisher.address output
    }
    {
      format.book.crossref output.nonnull
    }
  if$
  format.date "year" output.check
  new.sentence
  format.book.pages output
  new.sentence
  format.editiontitle output
  format.editionsubtitle output
  format.voledition output
  new.sentence
  format.notes output
  format.url output
  new.sentence
  format.isbn output
  format.doi output
  new.sentence
  fin.entry
}

FUNCTION {inbook}                                 %% ČÁSTI MONOGRAFIÍ - KAPITOLY 
{  output.bibitem
  format.authors output
  new.sentence   
  format.btitle "title" output.check
  format.subtitle output
  new.sentence
  format.editor output 
  format.translator output
  format.illustrator output
  format.redactor output
  format.others output
  new.sentence
  format.edition output
  new.sentence
  crossref missing$
    { format.bvolume output
      format.number.series output
      format.publisher.address output
    }
    {
      format.book.crossref output.nonnull
    }
  if$
  format.date "year" output.check
  new.sentence
  format.chapter output
  format.citpages output
  new.sentence
  format.editiontitle output
  format.editionsubtitle output
  format.voledition output
  new.sentence
  format.notes output
  format.url output
  new.sentence
  format.isbn output
  format.doi output
  new.sentence
  fin.entry
}

FUNCTION {proceedings}                                                %% SERIÁLY
{ output.bibitem
  format.journaltitle output
  format.journalsubtitle output
  new.sentence
  crossref missing$
    { format.bvolume output
      format.number.series output
      format.publisher.address output
    }
    {
      format.book.crossref output.nonnull
    }
  if$
  format.date "year" output.check
  new.sentence
  format.notes output
  format.url output
  new.sentence
  format.issn output
  format.doi output
  new.sentence
  fin.entry
}

FUNCTION {inproceedings}                               %% ČÁSTI SERIÁLŮ - ČLÁNKY
{ output.bibitem
  format.authors output
  new.sentence 
  format.titlenorm output
  format.subtitlenorm output
  new.sentence
  format.translator output
  format.illustrator output
  format.others output
  new.sentence
  format.journaltitle output
  format.journalsubtitle output
  new.sentence
  format.date "year" output.check
  format.volume output
  format.number output
  format.citpages output
  new.sentence
  format.notes output
  format.url output
  new.sentence
  format.issn output
  format.doi output
  new.sentence
  fin.entry
}

FUNCTION {mastersthesis}                                   %% KVALIFIKAČNÍ PRÁCE
{ output.bibitem
  format.authors output
  new.sentence   
  format.btitle "title" output.check
  format.subtitle output
  format.publishtype output
  new.sentence
  crossref missing$
    { format.bvolume output
      format.number.series output
      format.publisher.address output
    }
    {
      format.book.crossref output.nonnull
    }
  if$
  format.date "year" output.check
  new.sentence
  format.book.pages output
  format.attachs output
  new.sentence
  format.supervisor output 
  new.sentence
  format.notes output
  format.url output
  new.sentence
  format.isbn output
  format.doi output
  new.sentence
  fin.entry
}

FUNCTION {onlineweb}                                           %% WEBOVÁ STRÁNKA
{ output.bibitem
  format.authors output
  new.sentence   
  format.btitle "title" output.check
  format.onlinesubtitle output
  format.editor output 
  format.translator output
  format.illustrator output
  format.redactor output
  format.others output
  new.sentence
  format.edition output
  new.sentence
  crossref missing$
    { format.bvolume output
      format.number.series output
      format.publisher.address output
    }
    {
      format.book.crossref output.nonnull
    }
  if$
  format.date "year" output.check
  format.refresh output
  format.cited output
  new.sentence
  format.citpages output
  new.sentence
  format.editiontitle output
  format.editionsubtitle output
  format.voledition output
  new.sentence
  format.notes output
  format.url output
  new.sentence
  format.isbn output
  format.issn output
  format.doi output
  new.sentence
  fin.entry
}

FUNCTION {mediaproceedings}                               %% ELEKTRONICKÝ SERIÁL
{ output.bibitem
  format.journaltitle output
  format.journalsubtitle output
  format.howpublished output
  new.sentence
  crossref missing$
    { format.bvolume output
      format.number.series output
      format.publisher.address output
    }
    {
      format.book.crossref output.nonnull
    }
  if$
  format.date "year" output.check
  format.cited output
  new.sentence
  format.notes output
  new.sentence
  format.url output
  new.sentence
  format.issn output
  format.doi output
  new.sentence
  fin.entry
}

FUNCTION {inmediaproceedings}                             %% ELEKTRONICKÝ ČLÁNEK
{ output.bibitem
  format.authors output
  new.sentence 
  format.titlenorm output
  format.subtitlenorm output
  new.sentence
  format.translator output
  format.illustrator output
  format.others output
  new.sentence
  format.journaltitle output
  format.journalsubtitle output
  format.howpublished output
  new.sentence
  format.date "year" output.check
  format.volume output
  format.number output
  format.refresh output
  format.cited output
  new.sentence
  format.citpages output
  new.sentence
  format.notes output
  new.sentence
  format.url output
  new.sentence
  format.issn output
  format.doi output
  new.sentence
  fin.entry
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% END OF BLOCK  %%%%%%%%$$$$$$$$$$$%%%%%%%%%$$$$$$$

FUNCTION {booklet}
{ output.bibitem
  format.authors output
  add.colon
  format.title "title" output.check
  new.sentence
  howpublished "howpublished" bibinfo.check output
  address "address" bibinfo.check output
  format.date output
  format.isbn output
  format.book.pages output
  format.doi output
  format.note output
  format.eprint output
  fin.entry
  write.url
}



FUNCTION {incollection}
{ output.bibitem
  format.authors "author" output.check
  add.colon
  format.title "title" output.check
  new.sentence
  crossref missing$
    { format.in.ed.booktitle "booktitle" output.check
      format.number.series output
      format.chapter.pages output
      format.publisher.address output
      format.edition output
      format.date "year" output.check
      format.isbn output
    }
    { format.incoll.inproc.crossref output.nonnull
      format.chapter.pages output
    }
  if$
  format.pages "pages" output.check
  format.doi output
  format.note output
  format.eprint output
  fin.entry
  write.url
}

FUNCTION {conference} { inproceedings }
FUNCTION {manual}
{ output.bibitem
  author empty$
    { organization "organization" bibinfo.check
      duplicate$ empty$ 'pop$
        { output
          address "address" bibinfo.check output
        }
      if$
    }
    { format.authors output.nonnull }
  if$
  add.colon
  format.btitle "title" output.check
  new.sentence
  author empty$
    { organization empty$
        {
          address "address" bibinfo.check output
        }
        'skip$
      if$
    }
    {
      organization "organization" bibinfo.check output
      address "address" bibinfo.check output
    }
  if$
  format.edition output
  format.date output
  format.doi output
  format.note output
  format.eprint output
  fin.entry
  write.url
}

FUNCTION {misc}
{ output.bibitem
  format.authors output
  add.colon
  format.title output
  new.sentence
  howpublished "howpublished" bibinfo.check output
  format.date output
  format.doi output
  format.note output
  format.eprint output
  fin.entry
  write.url
  empty.misc.check
}
FUNCTION {phdthesis}
{ output.bibitem
  format.authors "author" output.check
  add.colon
  format.btitle
  "title" output.check
  new.sentence
  bbl.phdthesis format.thesis.type output.nonnull
  address "address" bibinfo.check output
  format.date "year" output.check
  format.doi output
  format.note output
  format.eprint output
  fin.entry
  write.url
}

FUNCTION {techreport}
{ output.bibitem
  format.authors "author" output.check
  add.colon
  format.title
  "title" output.check
  new.sentence
  format.tr.number output.nonnull
  institution "institution" bibinfo.warn output
  address "address" bibinfo.check output
  format.date "year" output.check
  format.doi output
  format.note output
  format.eprint output
  fin.entry
  write.url
}

FUNCTION {unpublished}
{ output.bibitem
  format.authors "author" output.check
  add.colon
  format.title "title" output.check
  format.date output
  format.doi output
  format.note "note" output.check
  format.eprint output
  fin.entry
  write.url
}

FUNCTION {default.type} { misc }
READ
FUNCTION {sortify}
{ purify$
  "l" change.case$
}
INTEGERS { len }
FUNCTION {chop.word}
{ 's :=
  'len :=
  s #1 len substring$ =
    { s len #1 + global.max$ substring$ }
    's
  if$
}
FUNCTION {sort.format.names}
{ 's :=
  #1 'nameptr :=
  ""
  s num.names$ 'numnames :=
  numnames 'namesleft :=
    { namesleft #0 > }
    { s nameptr
      "{ll{ }}{  f{ }}{  jj{ }}"
      format.name$ 't :=
      nameptr #1 >
        {
          nameptr #3
          #1 + =
          numnames #3
          > and
            { "others" 't :=
              #1 'namesleft := }
            'skip$
          if$
          "   "  *
          namesleft #1 = t "others" = and
            { "zzzzz" * }
            { t sortify * }
          if$
        }
        { t sortify * }
      if$
      nameptr #1 + 'nameptr :=
      namesleft #1 - 'namesleft :=
    }
  while$
}

FUNCTION {sort.format.title}
{ 't :=
  "A " #2
    "An " #3
      "The " #4 t chop.word
    chop.word
  chop.word
  sortify
  #1 global.max$ substring$
}
FUNCTION {author.sort}
{ author empty$
    { key empty$
        { "to sort, need author or key in " cite$ * warning$
          ""
        }
        { key sortify }
      if$
    }
    { author sort.format.names }
  if$
}
FUNCTION {author.editor.sort}
{ author empty$
    { editor empty$
        { key empty$
            { "to sort, need author, editor, or key in " cite$ * warning$
              ""
            }
            { key sortify }
          if$
        }
        { editor sort.format.names }
      if$
    }
    { author sort.format.names }
  if$
}
FUNCTION {author.organization.sort}
{ author empty$
    { organization empty$
        { key empty$
            { "to sort, need author, organization, or key in " cite$ * warning$
              ""
            }
            { key sortify }
          if$
        }
        { "The " #4 organization chop.word sortify }
      if$
    }
    { author sort.format.names }
  if$
}
FUNCTION {editor.organization.sort}
{ editor empty$
    { organization empty$
        { key empty$
            { "to sort, need editor, organization, or key in " cite$ * warning$
              ""
            }
            { key sortify }
          if$
        }
        { "The " #4 organization chop.word sortify }
      if$
    }
    { editor sort.format.names }
  if$
}
FUNCTION {presort}
{ type$ "book" =
  type$ "inbook" =
  or
    'author.editor.sort
    { type$ "proceedings" =
        'editor.organization.sort
        { type$ "manual" =
            'author.organization.sort
            'author.sort
          if$
        }
      if$
    }
  if$
  "    "
  *
  year field.or.null sortify
  *
  "    "
  *
  title field.or.null
  sort.format.title
  *
  #1 entry.max$ substring$
  'sort.key$ :=
}
ITERATE {presort}
SORT
STRINGS { longest.label }
INTEGERS { number.label longest.label.width }
FUNCTION {initialize.longest.label}
{ "" 'longest.label :=
  #1 'number.label :=
  #0 'longest.label.width :=
}
FUNCTION {longest.label.pass}
{ number.label int.to.str$ 'label :=
  number.label #1 + 'number.label :=
  label width$ longest.label.width >
    { label 'longest.label :=
      label width$ 'longest.label.width :=
    }
    'skip$
  if$
}
EXECUTE {initialize.longest.label}
ITERATE {longest.label.pass}
FUNCTION {begin.bib}
{ preamble$ empty$
    'skip$
    { preamble$ write$ newline$ }
  if$
  "\begin{thebibliography}{"  longest.label  * "}" *
  write$ newline$
  "\providecommand{\url}[1]{\texttt{#1}}"
  write$ newline$
  "\providecommand{\urlprefix}{Dostupné z: \textless}"
  write$ newline$
  "\providecommand{\urlsuffix}{\textgreater}"
  write$ newline$
  "\expandafter\ifx\csname urlstyle\endcsname\relax"
  write$ newline$
  "  \providecommand{\doi}[1]{doi:\discretionary{}{}{}#1}\else"
  write$ newline$
  "  \providecommand{\doi}{doi:\discretionary{}{}{}\begingroup \urlstyle{rm}\Url}\fi"
  write$ newline$
  "\providecommand{\selectlanguage}[1]{\relax}"
  write$ newline$
  "\providecommand{\tg}[1]{\textgreater .}"
  write$ newline$
  "\providecommand{\eprint}[2][]{\url{#2}}"
  write$ newline$
}
EXECUTE {begin.bib}
EXECUTE {init.state.consts}
ITERATE {call.type$}
FUNCTION {end.bib}
{ newline$
  "\end{thebibliography}" write$ newline$
}
EXECUTE {end.bib}
%% End of customized bst file
%%
%% End of file `czechiso.bst'.
