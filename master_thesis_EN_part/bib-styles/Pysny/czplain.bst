%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Projekt:     IBP - Bakalarska prace
% Nazev prace: BibTeX styl pro CSN ISO 690 a CSN ISO 690-2
% Autor:       Radek Pysny, xpysny00
% URI:         http://www.fit.vutbr.cz/study/DP/BP.php?id=7848
%
% Soubor:      czplain.bst (vznikl upravou plain.bst)
% Datum:       Vytvoren 15. unora 2009.
%              Posledni uprava 10. kveten 2009, 16:55.
% Popis:       Cesky bibliograficky styl.
% Pouziti:
% Kodovani:    UTF-8
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%% VOLBY PRO NASTAVENI BIBLIOGRAFICKEHO STYLU %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% -- Maximalni pocet zpracovanych autoru.
% Pokud obsahuje polozka author seznam o vice nez opt.aa autoru, objevi se
% v bibliograficke citaci prave opt.aa autoru. Tento vycet autoru bude zakoncen
% retezcem urcenym volbou opt.etal.
FUNCTION {opt.aa} { #3 }
% FUNCTION {opt.aa} { #4 }

% -- Maximalni pocet zpracovanych editoru.
% Analogie k volbe opt.aa.
% FUNCTION {opt.ae} { #2 }
FUNCTION {opt.ae} { #3 }
% FUNCTION {opt.ae} { #4 }

% -- Oddelovac mezi jednotlivymi jmeny ve vyctu.
% Pouziva se pro spojeni jmen ve vyctu. Vyjimkou jsou posledni dve jmena, ktera
% jsou spojena pomoci retezce urceneho volbou opt.sep.ln.
FUNCTION {opt.sep.bn} { ", " }
% FUNCTION {opt.sep.bn} { " -- " }

% -- Oddelovac mezi poslednimi dvema jmeny ve vyctu.
FUNCTION {opt.sep.ln} { " a~" }
% FUNCTION {opt.sep.ln} { " -- " }

% -- Naznak nedokonceneho vyctu jmen.
% Pokud byl presazen pocet jmen danych limitujicimi volbami opt.aa nebo opt.ae.
% Dale se pouzije tehdy, kdyz je misto posledniho jmena pouzito klicove slovo
% "others".
FUNCTION {opt.etal} { "et~al." }
% FUNCTION {opt.etal} { "aj." }
% FUNCTION {opt.etal} { "a kol." }

% -- Oznaceni editora (redaktora).
% Jmena editoru jsou od autoru odlisena retezcem danym touto volbou.
FUNCTION {opt.ed} { "(ed.)" }
% FUNCTION {opt.ed} { "(red.)" }
% FUNCTION {opt.ed} { "" }

% -- Pouzivat oznaceni editora (redaktora) za kazdym jmenem.
% Urcuje, kde se pouzije oznaceni opt.ed. Bud lze pouzit oznaceni za kazdym
% jmenem nebo jen na konci prvku.
FUNCTION {opt.ed.all} { #0 }     % pouze na konci prvku
% FUNCTION {opt.ed.all} { #1 }    % za kazdym jmenem

% -- Oddelovac mezi prvky primarni odpovednost a titul.
FUNCTION {opt.sep.a} { "." }
% FUNCTION {opt.sep.a} { ":" }

% -- Oddelovac mezi mistem a vydavatelem (popr. skolou nebo instituci).
FUNCTION {opt.sep.p} { ": " }
% FUNCTION {opt.sep.p} { " : " }
% FUNCTION {opt.sep.p} { ", " }

% -- Oddelovac mezi titulem a podtitulem.
% Je-li zadan titul i podtitul, je tento retezec pouzit jako oddelovac mezi
% temito prvky.
FUNCTION {opt.sep.t} { ": " }
% FUNCTION {opt.sep.t} { " : " }

% -- Oznaceni rozsahu u akademickych praci.
% U akademickych praci mate pomoci teto volby moznost urcit, zda-li bude rozsah
% techto praci udavan ve stranach nebo v listech.
FUNCTION {opt.pages} { "s." }    % pocet stran
% FUNCTION {opt.pages} { "l." }   % pocet listu

% -- Vyber z dvou pouzivanych tvaru bibliografickych citaci akademickych praci.
% #0 -- zakladni tvar pouziva rozmisteni prvku odpovidajici monografii
% #1 -- tvor, ktery pouziva napr. csplainnat.bst
FUNCTION {opt.thesis} { #0 }     % zakladni verze
% FUNCTION {opt.thesis} { #1 }    % alternativni verze

% -- Zacatek prvku dostupnost.
% Tento prepinac ovlivnuje text, ktery bude zobrazen pred URL adresou.
FUNCTION {opt.url} { "Dostupn{\'{e}} na: " }
% FUNCTION {opt.url} { "Dostupn{\'{e}} z: " }
% FUNCTION {opt.url} { "Dostupn{\'{e}} na WWW: " }

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%% DEKLARACE POLOZEK A PROMENNYCH %%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Polozky, ktere jsou stylem akceptovany a zpracovany.
ENTRY
  { address
    author
    booktitle
    booksubtitle    % podtitul knihy (napr u sborniku)
    cited           % datum citace
    contrybutory    % podrizena odpovednost
    edition
    editor
    howpublished    % druh nosice
    chapter
    institution
    inserts         % pocet stran priloh
    isbn            % standardni cislo
    issn            % standardni cislo
    journal
    key
    month
    note
    number
    organization
    pages
    publisher
    revised         % datum revize/aktualizace
    school
    series
    subtitle        % podtitul
    title
    type
    url             % dostupnost
    version         % verze u el.dok.
    volume
    year
  }
  { }
  { label }

% Celocislene promenne. U kazde (krome konstant, ktere jsou pouze inicializovany
% ve funkci init.state.consts -- before.all, mid.sentence, after.sentence,
% after.block) jsou vyjmenovany funkce, kde dochazi ke zmenam dane promenne.
%
% output.state -- output.nonnull, output.bibitem, new.block, new.sentance
%
% ord -- is.ord
%
% ptr, i, x -- str.to.int
%
% numnames, namesleft, nameptr -- format.names, format.names.ed,
%                                 sort.format.names
INTEGERS { output.state before.all mid.sentence after.sentence after.block
           ord ptr i x numnames namesleft nameptr }

% Retezcove promenne. U kazde jsou vyjmenovany funkce, kde je promenna menena.
%
% s -- output.nonnull, format.names, format.names.ed, format.journal.issue,
%      format.thesis.info, format.thesis.range, chop.word, sort.format.names
%
% t -- output.check, dashify, str.to.int, format.names, format.names.ed,
%      format.full.date, sort.format.names, sort.format.title
%
% u -- is.ord, tie.or.connnect, comma.connect
STRINGS { s t u }

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%% DEFINICE ZKRATEK -- CESKE NAZVY MESICU %%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

MACRO {jan} {"leden"}

MACRO {feb} {"únor"}

MACRO {mar} {"březen"}

MACRO {apr} {"duben"}

MACRO {may} {"květen"}

MACRO {jun} {"červen"}

MACRO {jul} {"červenec"}

MACRO {aug} {"srpen"}

MACRO {sep} {"září"}

MACRO {oct} {"říjen"}

MACRO {nov} {"listopad"}

MACRO {dec} {"prosinec"}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%% MIRNE UPRAVENE FUNKCE PREVZATE Z plain.bst %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Inicializace konstant nutnych pro spravnou funkci samotneho stylu.
%
% void init.state.consts ()
% {
%   int before.all = 0;
%   int mid.sentence = 1;
%   int adter.sentence = 2;
%   int after.block = 3;
% }
FUNCTION {init.state.consts}
{ #0 'before.all :=
  #1 'mid.sentence :=
  #2 'after.sentence :=
  #3 'after.block :=
}

% Vystup jiz formatovaneho pole, ktere je urcite neprazdne. Format vystupu je
% ovlivnen vystupnim stavem (tj. stavovou promennou output.state). Samotny
% vystup je zpozdeny (k vytisteni aktualni hodnoty dojde az pri pristim volani
% teto funkce) kvuli rozhodovani o pouzitem oddelovaci (carka nebo tecka).
%
% void output.nonnull ()
% {
%   s = pop();
%   if (output.state == mid.sentence)
%   {
%     write(pop() * " ");    // zde byla carka!!!
%   } else
%   {
%     if (output.state == after.block)
%     {
%       write(add.period(pop()));
%       flush();
%       write("\newblock ");
%     } else
%     {
%       if (output.state == before.all)
%       {
%         write(pop());
%       } else
%       {
%         write(add.period(pop()) * " ");
%       }
%     }
%   }
%   push(s);
% }
FUNCTION {output.nonnull}
{ 's :=
  output.state mid.sentence =
  { " " * write$ }                %% Uprava: Nahrada ", " za " "!
  {  output.state after.block =
    { add.period$ write$
      newline$
      "\newblock " write$
    }
    { output.state before.all =
       { write$ }
      { add.period$ " " * write$ }
      if$
    }
    if$
    mid.sentence 'output.state :=
  }
  if$
  s
}

% Pri vyskytu neprazdne hodnoty na vrcholu zasobniku provede jeji vystup pomoci
% funkce output.nonnull. V opacnem pripade ji jen odstrani ze zasobniku.
%
% /** prepis do pseudokodu bez vyuziti zasobniku **/
% void output (string string.to.write)
% {
%   if (empty$(string.to.write))
%   { } else
%   {
%     output.nonnull(string.to.write);
%   }
% }
FUNCTION {output}
{ duplicate$ empty$
  { pop$ }
  { output.nonnull }
  if$
}

% Pri vyskytu neprazdne hodnoty na vrcholu zasobniku provede jeji vystup pomoci
% funkce output.nonnull. V opacnem pripade ji jen odstrani ze zasobniku
% a vypise na chybovy vystup varovani o chybejici hodnote. Pouziva se pro
% informovani uzivatele o chybejici hodnote, ktera je dle ceske normy povinna.
%
% /** prepis do pseudokodu bez vyuziti zasobniku **/
% void output.check (string type.of.field string string.to.write)
% {
%   t = type.of.field;
%   if (empty$(string.to.write))
%   {
%     warning$("empty" * t * " in " * cite$())
%   } else
%   {
%     output.nonnull(string.to.write);
%   }
% }
FUNCTION {output.check}
{ 't :=
  duplicate$ empty$
  { pop$ "empty " t * " in " * cite$ * warning$ }
  { output.nonnull }
  if$
}

% Vypise zacatek bibliograficke citace.
%
% void output.bibitem ()
% {
%   newline$();
%   write$("\bibitem{");
%   write$(cite$);
%   write$("}");
%   newline$();
%   push("");
%   int output.state = before.all;
% }
FUNCTION {output.bibitem}
{ newline$
  "\bibitem{" write$
  cite$ write$
  "}" write$
  newline$
  ""
  before.all 'output.state :=
}

% Zakonceni polozky (teckou).
%
% void fin.entry ()
% {
%   write(add.period$(pop()));
%   newline$();
% }
FUNCTION {fin.entry}
{ add.period$ write$
  newline$
}

% Zmena stavu: {mid.sentence; after.sentence} => after.block.
%
% void new.block ()
% {
%   if (output.state == before.all)
%   { } else
%   {
%     output.state = after.block;
%   }
% }
FUNCTION {new.block}
{ output.state before.all =
  'skip$
  { after.block 'output.state := }
  if$
}

% Zmena stavu: mid.sentence => after.sentence.
%
% void new.sentence ()
% {
%   if (output.state == after.block)
%   { } else
%   {
%     if (output.state == before.all)
%     { } else
%     {
%       output.state = after.sentence;
%     }
%   }
% }
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

% Negace vyhodnocene podminky.
%
% int not (int bool)
% {
%   if (bool)
%   {
%     return 0; // false
%   } else
%   {
%     return 1; // true
%   }
% }
FUNCTION {not}
{ { #0 }
  { #1 }
  if$
}

% Logicky soucin dvou podminek.
%
% int and (int bool1, int bool2)
% {
%   if (bool2)
%   {
%     return bool1;
%   } else
%   {
%     return 0;
%   }
% }
FUNCTION {and}
{ 'skip$
  { pop$ #0 }
  if$
}

% Logicky soucet dvou podminek.
%
% int or (int bool1, int bool2)
% {
%   if (bool2)
%   {
%     return 1;
%   } else
%   {
%     return bool1;
%   }
% }
FUNCTION {or}
{ { pop$ #1 }
  'skip$
  if$
}

% Zacatek noveho bloku pri neprazne hodnote na vrcholu zasobniku.
%
% void new.block.checka (int.or.string anything.from.the.top)
% {
%   if (empty$(anything.from.the.top))
%   { } else
%   {
%     new.block();
%   }
% }
FUNCTION {new.block.checka}
{ empty$
  'skip$
  { new.block }
  if$
}

% Zacatek noveho bloku pri 2 neprazdnych hodnotach z vrcholu zasobniku.
%
% void new.block.checkb (int.or.string anything.under.the.top,
%                           int.or.string anything.from.the.top)
% {
%   if ( (empty$(anything.from.the.top)) && (empty$(anything.under.the.top)) )
%   { } else
%   {
%     new.block();
%   }
% }
FUNCTION {new.block.checkb}
{ empty$
  swap$ empty$
  and
  'skip$
  { new.block }
  if$
}

% Zacatek nove vety pri neprazne hodnote na vrcholu zasobniku.
%
% void new.sentence.checka (int.or.string anything.from.the.top)
% {
%   if (empty$(anything.from.the.top))
%   { } else
%   {
%     new.sentence();
%   }
% }
FUNCTION {new.sentence.checka}
{ empty$
  'skip$
  { new.sentence }
  if$
}

% Zacatek nove vety pri 2 neprazdnych hodnotach z vrcholu zasobniku.
%
% void new.sentence.checkb (int.or.string anything.under.the.top,
%                           int.or.string anything.from.the.top)
% {
%   if ( (empty$(anything.from.the.top)) && (empty$(anything.under.the.top)) )
%   { } else
%   {
%     new.sentence();
%   }
% }
FUNCTION {new.sentence.checkb}
{ empty$
  swap$ empty$ and
  'skip$
  { new.sentence }
  if$
}

% Vrati hodnoty polozky (ulozene na vrcholu zasobniku) nebo prazdny retezec.
%
% int.or.string field.or.null (int.or.string anything.from.the.top)
% {
%   if (empty$(anything.from.the.top))
%   {
%     return "";
%   } else
%   {
%     return anything.from.the.top;
%   }
% }
FUNCTION {field.or.null}
{ duplicate$ empty$
  { pop$ "" }
  'skip$
  if$
}

% Vypis chybove hlasky pro pripady, kdyz jsou vyplnene dve polozky, jejichz
% pouziti se vzajemne vylucuje. Vola se s dvema argumenty -- prvni z nich je
% retezec s nazvy obou poli (kvuli vypisu chybove hlasky) a druhy je obsah
% jednoho z poli (kontrola druheho musi probehnout pred volanim teto funkce).
%
% void either.or.check (string field.names, int.or.string one.of.fields)
% {
%   if (empty$(one.of.fields))
%   { } else
%   {
%     warning$(field.names * "can't use both " * " fields in " * cite$());
%   }
% }
FUNCTION {either.or.check}
{ empty$
  { pop$ }
  { "can't use both " swap$ * " fields in " * cite$ * warning$ }
  if$
}

% Provede zvyrazneni hodnoty na vrcholu zasobniku (uzavre ji mezi "{\em"
% a "}"). Nepouziva kurzivni korekci.
%
% string emphasize (string x)
% {
%   if (empty$(x))
%   {
%     return "";
%   } else
%   {
%     return "{\em " * x * "}";
%   }
% }
FUNCTION {emphasize}
{ duplicate$ empty$
  { pop$ "" }
  { "{\em " swap$ * "}" * }
  if$
}

% Nahradi kazdy vyskyt znaku '-' za dvojznak "--".
%
% string dashify (string to.dashify)
% {
%   t = to.dashify;
%   push("");
%   while (!empty$(t))
%   {
%     if (substring$(t, 1, 1) == "-")
%     {
%       if (substring$(t, 1, 2) == "--")
%       {
%         while (substring$(t, 1, 1) == "-")
%         {
%           push(pop() * "-");
%           t = substring$(t, 2, global.max$());
%         }
%       } else
%       {
%         push(pop() * "--");
%         t = substring$(t, 2, global.max$());
%       }
%     } else
%     {
%       push(pop() * substring$(t, 1, 1));
%       t = substring$(t, 2, global.max$());
%     }
%   }
% }
FUNCTION {dashify}
{ 't :=
  ""
  { t empty$ not }
  { t #1 #1 substring$ "-" =
   { t #1 #2 substring$ "--" =
     { { t #1 #1 substring$ "-" = }
      { "-" *
        t #2 global.max$ substring$ 't :=
      }
       while$
     }
     { "--" *
       t #2 global.max$ substring$ 't :=
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%% VLASTNI KOD -- POMOCNE FUNKCE %%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Prevod retezce na cislo. Ocekava se, ze se zavola az po testu pomoci funkce
% 'is.ord'. Na vstupu ocekava neprazdny retezec tvoreny jen cislicemi.
%
% int str.to.int (string to.convert)
% {
%   t = to.convert;
%   int x = 0;
%   int ptr = 0;
%   while (ptr text.length$(t) < )
%   {
%     push(x);
%     i = 9;
%     while (i > 0)
%     {
%       push(pop() + x);
%       i--;
%     }
%     ptr++;
%     x = chr.to.int$(substring$(t, ptr, 1)) - 48 + pop();
%   }
%   return x;
% }
FUNCTION {str.to.int}
{ 't :=
  #0 'x :=
  #0 'ptr :=
  { ptr t text.length$ < }
  { x
    #9 'i :=
    { i #0 > }
    { x +
      i #1 - 'i :=
    }
    while$
    ptr #1 + 'ptr :=
    t ptr #1 substring$ chr.to.int$ #48 - + 'x :=
  }
  while$
  x
}

% Prvni pismeno retezce na vrcholu zasobniku prevede na verzalku.
%
% string capitalize (string to.capitalize)
% {
%   if (empty$(to.capitalize))
%   { } else
%   {
%     return change.case$(substring$(to.capitalize, 1, 1), "u") *
%            substring$(to.capitalize, 2, global.max$());
%   }
% }
FUNCTION {capitalize}
{ duplicate$ empty$
  'skip$
  { duplicate$ #1 #1 substring$ "u" change.case$
    swap$ #2 global.max$ substring$ *
  }
  if$
}

% Spojuje dva retezce z vrcholu zasobniku. Tyto dva retezce jsou oddeleny
% mezerou ci nezlomitelnou mezerou. Retezec na vrcholu zasobniku je pripojen
% za druhy retezec.
%
% Pokud je jeden z retezcu prazdny, je vracen jen druhy z nich bez jakychkoliv
% uprav. Jsou-li prazdne oba retezce, je vracen taktez prazdny retezec.
%
% string tie.or.connect (string under.the.top, string from.the.top)
% {
%   string u = from.the.top;
%   if (empty$(under.the.top))
%   {
%     return u;
%   } else
%   {
%     if (empty$(u))
%     { } else
%     {
%       if (text.length$(u) < 3)
%       {
%         return under.the.top * "~" * u;
%       } else
%       {
%         return under.the.top * " " * u;
%       }
%     }
%   }
% }
FUNCTION {tie.or.connect}
{ 'u :=
  duplicate$ empty$
  { pop$ u }
  { u empty$
    'skip$
    { u text.length$ #3 <
      { "~" * u * }
      { " " * u * }
      if$
    }
    if$
  }
  if$
}

% Spojuje dva retezce z vrcholu zasobniku. Tyto dva retezce jsou oddeleny
% carkou. Retezec na vrcholu zasobniku je pripojen za druhy retezec.
%
% Pokud je jeden z retezcu prazdny, je vracen jen druhy z nich bez jakychkoliv
% uprav. Jsou-li prazdne oba retezce, je vracen taktez prazdny retezec.
%
% string comma.connect (string under.the.top, string from.the.top)
% {
%   string u = from.the.top;
%   if (empty$(under.the.top))
%   {
%     return u;
%   } else
%   {
%     if (empty$(u))
%     { } else
%     {
%       return under.the.top * ", " * u;
%     }
%   }
% }
FUNCTION {comma.connect}
{ 'u :=
  duplicate$ empty$
  { pop$ u }
  { u empty$
    'skip$
    { ", " * u * }
    if$
  }
  if$
}

% Otestuje, zda je hodnota na vrcholu zasobniku tvorena pouze cislicemi.
%
% int is.ord (string x)
% {
%   string u = x;
%   int ord = 1;
%   while ( (ord) && (!empty(u)) )
%   {
%     if ( (chr.to.int$(substring$(u, 1, 1)) < 48) ||
%          (chr.to.int$(substring$(u, 1, 1)) > 57) )
%     {
%       ord = 0;
%     } else
%     {
%       u = substring(s, 2, global.max$());
%     }
%   }
%   return ord;
% }
FUNCTION {is.ord}
{ 'u :=
  #1 'ord :=
  { ord
    u empty$ not
    and
  }
  { u #1 #1 substring$
    duplicate$ chr.to.int$ #48 <  % < '0'
    swap$ chr.to.int$ #57 >       % > '9'
    or
    { #0 'ord := }
    { u #2 global.max$ substring$ 'u := }
    if$
  }
  while$
  ord
}

% Formatovaci retezec pro vkladani jmen dle ceske konvence pomoci funkce
% 'format.name$'.
%
% string cz.name.format ()
% {
%   return "{{\scshape\bgroup}ll{ }{\egroup}}{, f.}{ vv}";
% }
FUNCTION {cz.name.format}
{ "{{\sc\bgroup}ll{ }{\egroup}}{, f.}{ vv}" }

% Vraci nominativ mesice.
%
% /** prepis pseudokodu do funkce pracujici s polem **/
% string get.month.n (int n)
% {
%   int month = { 1 => "leden", "únor", "březen", "duben", "květen", "červen",
%                "červenec", "srpen", "září", "říjen", "listopad", "prosinec" };
%   if ( (n > 0) && (n < 13) )
%   {
%     return month[n];
%   } else
%   {
%     warning$("Month must be between 1 and 12!");
%     return "";
%   }
% }
FUNCTION {get.month.n}
{ duplicate$ #1 =
  { "leden" swap$ pop$ }
  { duplicate$ #2 =
    { "únor" swap$ pop$ }
    { duplicate$ #3 =
      { "březen" swap$ pop$ }
      { duplicate$ #4 =
        { "duben" swap$ pop$ }
        { duplicate$ #5 =
          { "květen" swap$ pop$ }
          { duplicate$ #6 =
            { "červen" swap$ pop$ }
            { duplicate$ #7 =
              { "červenec" swap$ pop$ }
              { duplicate$ #8 =
                { "srpen" swap$ pop$ }
                { duplicate$ #9 =
                  { "září" swap$ pop$ }
                  { duplicate$ #10 =
                    { "říjen" swap$ pop$ }
                    { duplicate$ #11 =
                      { "listopad" swap$ pop$ }
                      { duplicate$ #12 =
                        { "prosinec" swap$ pop$ }
                        { "" "Month must be between 1 and 12!" warning$ }
                        if$
                      }
                      if$
                    }
                    if$
                  }
                  if$
                }
                if$
              }
              if$
            }
            if$
          }
          if$
        }
        if$
      }
      if$
    }
    if$
  }
  if$
}

% Vraci genitiv mesice.
%
% /** prepis pseudokodu do funkce pracujici s polem **/
% string get.month.n (int n)
% {
%   int month = { 1 => "ledna", "února", "března", "dubna", "května", "června",
%                "července", "srpna", "září", "října", "listopadu", "prosince"};
%   if ( (n > 0) && (n < 13) )
%   {
%     return month[n];
%   } else
%   {
%     warning$("Month must be between 1 and 12!");
%     return "";
%   }
% }
FUNCTION {get.month.g}
{ duplicate$ #1 =
  { "ledna" swap$ pop$ }
  { duplicate$ #2 =
    { "února" swap$ pop$ }
    { duplicate$ #3 =
      { "března" swap$ pop$ }
      { duplicate$ #4 =
        { "dubna" swap$ pop$ }
        { duplicate$ #5 =
          { "května" swap$ pop$ }
          { duplicate$ #6 =
            { "června" swap$ pop$ }
            { duplicate$ #7 =
              { "července" swap$ pop$ }
              { duplicate$ #8 =
                { "srpna" swap$ pop$ }
                { duplicate$ #9 =
                  { "září" swap$ pop$ }
                  { duplicate$ #10 =
                    { "října" swap$ pop$ }
                    { duplicate$ #11 =
                      { "listopadu" swap$ pop$ }
                      { duplicate$ #12 =
                        { "prosince" swap$ pop$ }
                        { "" "Month must be between 1 and 12!" warning$ }
                        if$
                      }
                      if$
                    }
                    if$
                  }
                  if$
                }
                if$
              }
              if$
            }
            if$
          }
          if$
        }
        if$
      }
      if$
    }
    if$
  }
  if$
}

% Provede vystup. Je urcen jen pro vypsani primarni odpovednosti. Umoznuje
% pouziti volby 'opt.sep.a', ktera dovoluje pouzit jiny oddelovac mezi poli
% primarni odpovednosti a nazvu titulu. Dle zazitych zvyklosti v CR je jim ':'.
%
% Pouzivat pouze na zacatku bibliograficke citace! Jinde muze zpusobit prohozeni
% prvku.
%
% void output.authors (string formatted.authors)
% {
%   if (substring$(formatted.authors, #-1, #1) == opt.sep.a())
%   {
%     write$(formatted.authors);
%     newline$();
%     write("\newblock ");
%   } else
%   {
%     write$(formatted.authors * opt.sep.a());
%     newline$();
%     write("\newblock ");
%   }
% }
FUNCTION {output.authors}
{
  duplicate$ #-1 #1 substring$ opt.sep.a =
  { write$ newline$ "\newblock " write$ }
  { opt.sep.a *
    write$ newline$ "\newblock " write$
  }
  if$
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%% VLASTNI KOD -- FORMATOVACI FUNKCE %%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Formatovani jmen (pro primarni odpovednost).
%
% string format.names (string names)
% {
%   string s = names;
%   int numnames = num.names$(s);
%   int namesleft = numnames;
%   int nameptr = 1;
%   while ( (namesleft > 0) && (nameptr <= opt.aa()) )
%   {
%     t = format.name$(s, nameptr, cz.name.format());
%     if (nameptr == 1)
%     {
%       push(t);
%     } else
%     {
%       if (namesleft > 1)
%       {
%         push(pop() * opt.sep.bn() * t);
%       } else
%       {
%         if (purify$(t) == "others")
%         {
%           push(tie.or.connect(pop(), opt.etal()));
%         } else
%         {
%           push(pop() * opt.sep.ln() * t);
%         }
%       }
%     }
%     nameptr++;
%     namesleft--;
%   }
%   if (nameledt > 0)
%   {
%     push(tie.or.connect(pop(), opt.etal()));
%   }
%   return pop();
% }
FUNCTION {format.names}
{ 's :=                             % s <= polozka se jmeny
  s num.names$ 'numnames :=         % numnames <= pocet jmen v polozce
  numnames 'namesleft :=            % poznamena si pocet zbyvajicich jmen
  #1 'nameptr :=                    % nameptr <= ukazatel na prvni ze jmen
  { namesleft #0 >
    nameptr opt.aa > not
    and
  }
  { % cyklus zpracovani jednotlivych jmen
    s nameptr cz.name.format format.name$ 't :=
    nameptr #1 =
    { t }                           % prvni jmeno
    { namesleft #1 >                % dalsi jmena
      { opt.sep.bn t * * }
      { t purify$
        "others" =                  % kdyz po ocisteni zbyde klic. sl. "others"
        { opt.etal tie.or.connect } % vytiskne et al.
        { opt.sep.ln * t * }        % jinak posledni inicialy po spojce "a"
        if$
      }
      if$
    }
    if$
    nameptr #1 + 'nameptr :=        % posun ukazatele na dalsi jmeno
    namesleft #1 - 'namesleft :=    % snizeni poctu zbyvajicich jmen
  }
  while$
  namesleft #0 >                    % mozne pridani opt.etal
  { opt.etal tie.or.connect }
  'skip$
  if$
}

% Formatovani jmen editoru.
%
% string format.names.ed (string names)
% {
%   string s = names;
%   int numnames = num.names$(s);
%   int namesleft = numnames;
%   int nameptr = 1;
%   while ( (namesleft > 0) && (nameptr <= opt.aa()) )
%   {
%     t = format.name$(s, nameptr, cz.name.format());
%     if (nameptr == 1)
%     {
%       if (opt.ed.all())
%       {
%         push(tie.or.connect(t, opt.ed());
%       } else
%       {
%         push(t);
%       }
%     } else
%     {
%       if (namesleft > 1)
%       {
%         if (opt.ed.all())
%         {
%           push(tie.or.connect(pop() * opt.sep.bn() * t, opt.ed());
%         } else
%         {
%           push(pop() * opt.sep.bn() * t);
%         }
%       } else
%       {
%         if (purify$(t) == "others")
%         {
%           push(tie.or.connect(pop(), opt.etal()));
%         } else
%         {
%           if (opt.ed.all())
%           {
%             push(tie.or.connect(pop() * opt.sep.ln() * t, opt.ed());
%           } else
%           {
%             push(pop() * opt.sep.ln() * t);
%           }
%         }
%       }
%     }
%     nameptr++;
%     namesleft--;
%   }
%   if (nameledt > 0)
%   {
%     push(tie.or.connect(pop(), opt.etal()));
%   }
%   if (opt.ed.all())
%   {
%     return pop();
%   } else
%   {
%     return tie.or.connect(pop(), opt.ed());
%   }
% }
FUNCTION {format.names.ed}
{ 's :=                             % s <= polozka se jmeny
  s num.names$ 'numnames :=         % numnames <= pocet jmen v polozce
  numnames 'namesleft :=            % poznamena si pocet zbyvajicich jmen
  #1 'nameptr :=                    % nameptr <= ukazatel na prvni ze jmen
  { namesleft #0 >
    nameptr opt.ae > not
    and
  }
  { % cyklus zpracovani jednotlivych jmen
    s nameptr cz.name.format format.name$ 't :=
    nameptr #1 =                    % prvni jmeno
    { t
      opt.ed.all
      { opt.ed tie.or.connect }
      'skip$
      if$
    }
    { namesleft #1 >                % dalsi jmena
      { opt.sep.bn t * *
        opt.ed.all
        { opt.ed tie.or.connect }
        'skip$
        if$
      }
      { t purify$
        "others" =                  % kdyz po ocisteni zbyde klic. sl. "others"
        { opt.etal tie.or.connect } % vytiskne et al.
        { opt.sep.ln t * *          % jinak posledni inicialy po spojce "a"
          opt.ed.all
          { opt.ed tie.or.connect }
          'skip$
          if$
        }
        if$
      }
      if$
    }
    if$
    nameptr #1 + 'nameptr :=        % posun ukazatele na dalsi jmeno
    namesleft #1 - 'namesleft :=    % snizeni poctu zbyvajicich jmen
  }
  while$
  namesleft #0 >                    % mozne pripojeni opt.etal
  { opt.etal tie.or.connect }
  'skip$
  if$
  opt.ed.all                        % mozne pridani opt.ed na konec prvku
  'skip$
  { opt.ed tie.or.connect }
  if$
}

% Formatovani jmen autoru.
% Pokud je neprazdna polozka 'author', provede formatovani jmen pomoci funkce
% 'format.names'.
%
% string format.authors ()
% {
%   if (empty$(author))
%   {
%     return "";
%   } else
%   {
%     return format.names(author);
%   }
% }
FUNCTION {format.authors}
{ author empty$
  { "" }
  { author format.names }
  if$
}

% Formatovani jmen editoru.
% Pokud je neprazdna polozka 'editor', provede formatovani jmen pomoci funkce
% 'format.names.ed'.
%
% string format.editors ()
% {
%   if (empty$(editor))
%   {
%     return "";
%   } else
%   {
%     return format.names.ed(editor);
%   }
% }
FUNCTION {format.editors}
{ editor empty$
  { "" }
  { editor format.names.ed }
  if$
}

% Formatovani polozky primarni odpovednosti.
% Je-li zadana polozka 'author', provede jeji formatovani pomoci funkce
% 'format.authors'. Pokud je polozka 'author' prazdna, provede formatovani
% pomoci funkce 'format.editors'.
%
% void author.or.editor ()
% {
%   if (empty$(author))
%   {
%     if (empty$(format.editors()))
%     {
%       warning$("empty author and editor in " * cite$());
%     } else
%     {
%       output.authors(format.editors());
%     }
%   } else
%   {
%     output.authors(format.authors());
%   }
% }
FUNCTION {author.or.editor}
{ author empty$
  { format.editors
    duplicate$ empty$
    { pop$
      "empty author and editor in " cite$ * warning$
    }
    { output.authors }
    if$
  }
  { format.authors
    output.authors
  }
  if$
}

% Formatovani nazvu (napr. casopisu, zurnalu atp.).
% Pri zadane polozce 'subtitle' provede ji pripoji k obsahu polozky 'title'
% pomoci ": ". V nazvu je pak provedena zmena velikosti pismen.
%
% string format.title ()
% {
%   if (empty$(subtitle))
%   {
%     return capitalize(title);
%   } else
%   {
%     return capitalize(title) * opt.sep.t() * subtitle;
%   }
% }
FUNCTION {format.title}
{ subtitle empty$
  { title capitalize }
  { title capitalize
    opt.sep.t * subtitle *
  }
  if$
}

% Formatovani nazvu monograficke publikace.
% Pri zadane polozce 'subtitle' provede ji pripoji k obsahu polozky 'title'
% pomoci ": ". Pricemz na obe casti se provede zmena velikosti pismen
% a zvyrazneni. Pokud je polozka 'subtitle' prazdna, je provedena jen zmena
% velikosti pismen a jeji zvyrazneni.
%
% string format.btitle ()
% {
%   return emphasize(format.title());
% }
FUNCTION {format.btitle}
{ format.title emphasize
}

% Formatovani nazvu (napr. sbornik).
% Pri zadane polozce 'booksubtitle' provede ji pripoji k obsahu polozky
% 'booktitle' pomoci ": ". V nazvu je pak provedena zmena velikosti pismen
% a zvyrazneni kurzivou.
%
% string format.from.btitle ()
% {
%   if (empty$(booktitle))
%   {
%     warning$(empty booktitle in " * cite$());
%     push("");
%   } else
%   {
%     push(capitalize(booktitle));
%     if (empty$(booksubtitle))
%     { } else
%     {
%       push(pop() * opt.sep.t * booksubtitle);
%     }
%   }
%   return emphasize(pop());
% }
FUNCTION {format.from.btitle}
{ booktitle empty$
  { "empty booktitle in " cite$ * warning$
    ""
  }
  { booktitle capitalize
    booksubtitle empty$
    'skip$
    { opt.sep.t * booksubtitle * }
    if$
  }
  if$
  emphasize
}

% Formatovani druhu nosice.
%
% string format.howpublished ()
% {
%   if (empty$(howpublished))
%   {
%     return "";
%   } else
%   {
%     if (change.case(howpublished, "l") == "cd")
%     {
%       push("CD-ROM");
%     } else
%     {
%       if (change.case(howpublished, "l") == "online")
%       {
%         push("online");
%       } else
%       {
%         push(howpublished);
%       }
%     }
%     return "[" * pop() * "]";
%   }
% }
FUNCTION {format.howpublished}
{ howpublished empty$
  { "" }
  { howpublished "l" change.case$ "cd" =
    { "CD-ROM" }
    { howpublished "l" change.case$ "online" =
      { "online" }
      { howpublished }
      if$
    }
    if$
    "[" swap$ * "]" *
  }
  if$
}

% Formatovani vydani
%
% string format.edition ()
% {
%   if (empty$(edition))
%   {
%     push("");
%   } else
%   {
%     if (is.ord(edition))
%     {
%       push(edition * ". vyd.");
%     } else
%     {
%       push(edition);
%     }
%   }
%   if (!empty$(version))
%   {
%     push(comma.connect(pop(), version));
%   }
%   return pop();
% }
FUNCTION {format.edition}
{ edition empty$
  { "" }
  { edition is.ord
    { edition ". vyd." * }
    { edition }
    if$
  }
  if$
  howpublished empty$
  'skip$
  { version empty$
    'skip$
    { version comma.connect }
    if$
  }
  if$
}

% Formatovani mesice a roku
%
% string format.date ()
% {
%   if (empty$(month))
%   {
%     if (empty$(year))
%     {
%       warning$("empty year in " * cite$());
%       return "";
%     } else
%     {
%       return year;
%     }
%   } else
%   {
%     if (empty$(year))
%     {
%       warning$("just month (empty year) in " * cite$());
%       return "";
%     } else
%     {
%       if (is.ord(month))
%       {
%         return get.month.n(str.to.int(month)) * " " * year;
%       } else
%       {
%         return month * " " * year;
%       }
%     }
%   }
% }
FUNCTION {format.date}
{ month empty$
  { year empty$
    { "" "empty year in " cite$ * warning$ }
    { year }
    if$
  }
  { year empty$
    { "" "just month (empty year) in " cite$ * warning$ }
    { month duplicate$ is.ord
      { str.to.int get.month.n " " * year * }
      { " " * year * }
      if$
    }
    if$
  }
  if$
}

% Rozpoznani a prevod data z formatu '!yyyy-mm-dd'.
%
% string format.full.date (string date)
% {
%   string t = date;
%   if (text.length$(t) == 10)
%   {
%     if ( (is.ord(substring$(t, 1, 4))) && (substring$(t, 5, 1) == "-") &&
%          (is.ord(substring$(t, 6, 2))) && (substring$(t, 8, 1) == "-") &&
%          (is.ord(substring$(t, 9, 2))) )
%     {
%       if (substring$(t, 9, 1) == "0")
%       {
%         if (substring$(t, 10, 1) == "0")
%         {
%           warning$("day must be between 1 and 31 in " * cite$());
%         } else { }
%         push(substring$(t, 10, 1) * ".~");
%       } else
%       {
%         if ( ((chr.to.int$(substring$(t, 9, 1)) - 48) > 3) ||
%              ((substring$(t, 9, 1) == "3") &&
%               ((chr.to.int$(substring$(t, 10, 1)) - 48) > 1)) )
%         {
%           pop();
%           push(t);
%           warning$("day must be between 1 and 31 in " * cite$());
%         } else { }
%         push(substring$(t, 9, 2) * ".~");
%       }
%       if (substring$(t, 6, 1) == "0")
%       {
%         if (substring$(t, 7, 1) == "0")
%         {
%           pop();
%           push(t);
%           warning$("month must be between 1 and 12 in " * cite$());
%         } else
%         {
%           return pop() * get.month.g(chr.to.int$(substring$(t, 7, 1)) - 48) *
%                  " " * substring$(t, 1, 4));
%         }
%       } else
%       {
%         if ( (substring$(t, 6, 1) == "1") &&
%              ((chr.to.int$(substring$(t, 7, 1)) - 48) < 3) )
%         {
%           return pop() * get.month.g(chr.to.int$(substring$(t, 7, 1))
%                  - 48 + 10) * " " * substring$(t, 1, 4));
%         } else
%         {
%           pop();
%           push(t);
%           warning$("month must be between 1 and 12 in " * cite$());
%         }
%       }
%     } else
%     {
%       return t;
%     }
%   } else
%   {
%     return t;
%   }
% }
FUNCTION {format.full.date}
{ 't :=
  t text.length$ #11 =
  { t #1 #1 substring$ "!" =
    t #2 #4 substring$ is.ord
    t #6 #1 substring$ "-" =
    t #7 #2 substring$ is.ord
    t #9 #1 substring$ "-" =
    t #10 #2 substring$ is.ord
    and and and and and
    { t #10 #1 substring$ "0" =
      { t #11 #1 substring$ "0" =
        { "day must be between 1 and 31 in " cite$ * warning$ }
        'skip$
        if$
        t #11 #1 substring$ ".~" *
      }
      { t #10 #1 substring$ chr.to.int$ #48 - #3 >
        t #10 #1 substring$ "3" =
        t #11 #1 substring$ chr.to.int$ #48 - #1 >
        and or
        { pop$ t "day must be between 1 and 31 in " cite$ * warning$ }
        'skip$
        if$
        t #10 #2 substring$ ".~" *
      }
      if$
      t #7 #1 substring$ "0" =
      { t #8 #1 substring$ "0" =
        { pop$ t "month must be between 1 and 12 in " cite$ * warning$ }
        { t #8 #1 substring$ chr.to.int$ #48 - get.month.g *
          " " * t #2 #4 substring$ *
        }
        if$
      }
      { t #7 #1 substring$ "1" =
        t #8 #1 substring$ chr.to.int$ #48 - #3 <
        and
        { t #8 #1 substring$ chr.to.int$ #48 - #10 + get.month.g *
          " " * t #2 #4 substring$ *
        }
        { pop$ t "month must be between 1 and 12 in " cite$ * warning$ }
        if$
      }
      if$
    }
    { t }
    if$
  }
  { t }
  if$
}

% Predani udaju z data revize elektronickeho dokumentu.
%
% string format.revised ()
% {
%   if (empty$(howpublished))
%   {
%     return "";
%   } else
%   {
%     if (empty$(revised))
%     {
%        return "";
%     } else
%     {
%       return revised;
%     }
%   }
% }
FUNCTION {format.revised}
{ howpublished empty$
  { "" }
  { revised empty$
    { "" }
    { revised }
    if$
  }
  if$
}

% Formatovani udaju z data citace elektronickeho dokumentu.
%
% string format.cited ()
% {
%   if (empty$(howpublished))
%   {
%     return "";
%   } else
%   {
%     if (empty$(cited))
%     {
%       warning$("empty cited in " * cite$());
%       return "";
%     } else
%     {
%       return "[cit. " * format.full.date(cited) * "]";
%     }
%   }
% }
FUNCTION {format.cited}
{ howpublished empty$
  { "" }
  { cited empty$
    { "empty cited in " cite$ * warning$
      ""
    }
    { cited format.full.date
      "[cit. " swap$ * "]" *
    }
    if$
  }
  if$
}

% Formatovani nakladatelskych udaju.
%
% string format.publish.info ()
% {
%   if ( (empty$(address)) && (empty$(publisher)) )
%   {
%     string s = "";
%   } else
%   {
%     if (empty$(address))
%     {
%       s = "[b.m.]: ";
%     } else
%     {
%       s = address * ": ";
%     }
%     if (empty$(publisher))
%     {
%       s = s * "[b.n.]";
%     } else
%     {
%       s = s * publisher;
%     }
%   }
%   return s;
% }
FUNCTION {format.publish.info}
{ address empty$
  publisher empty$
  and
  { "" }
  { address empty$
    { "[b.m.]" }
    { address }
    if$
    opt.sep.p *
    publisher empty$
    { "[b.n.]" * }
    { publisher * }
    if$
  }
  if$
}

% Formatuje rozsah stran publikace.
%
% string format.range ()
% {
%   if (empty$(pages))
%   {
%     return "";
%   } else
%   {
%     return tie.or.connect(pages, "s.");
%   }
% }
FUNCTION {format.range}
{ pages empty$
  { "" }
  { pages "s." tie.or.connect }
  if$
}

% Formatovani edice a svazku monograficke publikace.
%
% string format.bvolume ()
% {
%   if (empty$(series))
%   {
%     return "";
%   } else
%   {
%     push(capitalize(series));
%     if (empty$(volume))
%     {
%       if (empty$(number))
%       { } else
%       {
%         if (is.ord(number))
%         {
%           return comma.connect(pop(), "č. " * number);
%         } else
%         {
%           return comma.connect(pop(), number);
%         }
%       }
%     } else
%     {
%       if (is.ord(volume))
%       {
%         return comma.connect(pop(), "č. " * volume);
%       } else
%       {
%         return comma.connect(pop(), volume);
%       }
%     }
%   }
% }
FUNCTION {format.bvolume}
{ series empty$
  { "" }
  { series capitalize
    volume empty$
    { number empty$
      'skip$
      { number is.ord
        { "č. " number * comma.connect }
        { number comma.connect }
        if$
      }
      if$
    }
    { volume is.ord
      { "sv. " volume * comma.connect }
      { volume comma.connect }
      if$
    }
    if$
  }
  if$
}

% Format dostupnosti.
%
% string format.url ()
% {
%   if (empty$(url))
%   {
%     return "";
%   } else
%   {
%     return tie.or.connect(opt.url(), "\url{"Dostupné na: <" * url * ">.}");
%   }
% }
FUNCTION {format.url}
{ url empty$
  { "" }
  { opt.url "{\tt " url * "}" * tie.or.connect }
  if$
}

% Format ISBN.
%
% string format.isbn ()
% {
%   if (empty$(isbn))
%   {
%     return "";
%   } else
%   {
%     return "ISBN " * isbn;
%   }
% }
FUNCTION {format.isbn}
{ isbn empty$
  { "" }
  { "ISBN " isbn * }
  if$
}

% Format nazvu serialove publikace.
%
% string format.journal ()
% {
%   if (empty$(journal))
%   {
%     return "";
%   } else
%   {
%     return emphasize(journal);
%   }
% }
FUNCTION {format.journal}
{ journal empty$
  { "" }
  { journal capitalize emphasize }
  if$
}

% Format nazvu lokace ve zdrojovem dokumentu.
%
% string format.pages ()
% {
%   if (empty$(pages))
%   {
%     return "";
%   } else
%   {
%     return "s.~" * dashify(pages);
%   }
% }
FUNCTION {format.pages}
{ pages empty$
  { "" }
  { "s.~" pages dashify * }
  if$
}

% Formatovani data vydani, rocniku a cisla publikace + datum revize/aktualizace
%   + darum citace + lokace ve zdrojovem dokumentu (rozsah stran).
%
% string format.journal.issue ()
% {
%   string s;
%   if (empty$(format.date()))
%   {
%     s = "";
%   } else
%   {
%     s = format.date();
%   }
%   if (!empty$(volume))
%   {
%     if (is.ord(volume))
%     {
%       s = comma.connect(s, "roč.~" * volume);
%     } else
%     {
%       s = comma.connect(s, volume);
%     }
%   }
%   if (empty$(number))
%   {
%     warning$("empty number in " * cite$);
%   } else
%   {
%     if (is.ord(number))
%     {
%       s = comma.connect(s, "č.~" * number);
%     } else
%     {
%       s = comma.connect(s, number);
%     }
%   }
%   if (s == "")
%   {
%     warning$("empty journal issue info in " * cite$);
%     return "";
%   } else
%   {
%     return s;
%   }
% }
FUNCTION {format.journal.issue}
{ format.date duplicate$ empty$
  { pop$ "" 's := }
  { 's := }
  if$
  volume empty$
  'skip$
  { volume is.ord
    { "roč.~" volume *
      s swap$ comma.connect 's :=
    }
    { s volume comma.connect 's := }
    if$
  }
  if$
  number empty$
  { "empty number in " cite$ * warning$ }
  { number is.ord
    { "č.~" number *
      s swap$ comma.connect 's :=
    }
    { s number comma.connect 's := }
    if$
  }
  if$
  s empty$
  { "empty journal issue info in " cite$ * warning$
    ""
  }
  { s }
  if$
}

% Format ISSN.
%
% string format.issn ()
% {
%   if (empty$(issn))
%   {
%     return "";
%   } else
%   {
%     return "ISBN " * issn;
%   }
% }
FUNCTION {format.issn}
{ issn empty$
  { "" }
  { "ISSN " issn * }
  if$
}

% Formatuje cislo svazku -- presne urceni casti pro @InBook.
%
% string format.vol ()
% {
%   if (empty$(volume))
%   {
%     push("");
%   } else
%   {
%     if (is.ord(volume))
%     {
%       push("sv.~" * volume);
%     } else
%     {
%       push(volume);
%     }
%   }
%   return capitalize(pop());
% }
FUNCTION {format.vol}
{ volume empty$
  { "" }
  { volume is.ord
    { "sv.~" volume * }
    { volume }
    if$
  }
  if$
  capitalize
}

% Formatuje zakladni informace (primarni odpovednost a titul) o sborniku pro
% bibliograficke citaci clanku ve sborniku.
%
% In <primarni odpovendost> opt.sep.a() <titul sborniku>.
%
% Pokud je <titlu sborniku> prazdny, netiskne se nic.
%
% void conference.basics ()
% {
%   if (empty$(editor))
%   {
%     if (empty$(organization))
%     {
%       warning$("empty editor and organization in " * cite$());
%       push("");
%     } else
%     {
%       if ((substring$(organization, -1, 1) == opt.sep.a())
%       {
%         push(capitalize(organization));
%       } else
%       {
%         push(capitalize(organization * opt.sep.a()));
%       }
%     }
%   } else
%   {
%     if ((substring$(format.editors(), -1, 1) == opt.sep.a())
%     {
%       push(format.editors());
%     } else
%     {
%       push(capitalize(format.editors() * opt.sep.a()));
%     }
%   }
%   push(tie.or.connect("In", pop()));
%   if (empty$(format.from.btitle()))
%   {
%     pop();
%     push("");
%   } else
%   {
%     push(pop() * format.from.btitle());
%   }
%   return pop();
% }
FUNCTION {conference.basics}
{ editor empty$
  { organization empty$
    { "empty editor and organization in " cite$ * warning$
      ""
    }
    { organization capitalize
      duplicate$ #-1 #1 substring$ opt.sep.a =
      'skip$
      { opt.sep.a * }
      if$
    }
    if$
  }
  { format.editors
    duplicate$ #-1 #1 substring$ opt.sep.a =
    'skip$
    { opt.sep.a * }
    if$
  }
  if$
  "In" swap$ tie.or.connect
  format.from.btitle
  duplicate$ empty$
  { pop$ }
  { tie.or.connect }
  if$
}

% Formatuje informace o akademicke (diplomova, dizertacni atp.) praci.
% Odlisuje se od beznych nakladatelskych informaci pouzitymi polozkami.
%
% string format.thesis.info ()
% {
%   string s = "";
%   if ( (empty$(address)) && (empty$(school)) )
%   {
%     warning$("empty address and school in " * cite$());
%   } else
%   {
%     if (empty$(address))
%     {
%       warning$("empty address in " * cite$());
%     } else
%     {
%       s = address;
%     }
%     if (empty$(school))
%     {
%       warning$("empty school in " * cite$());
%     } else
%     {
%       if (empty$(s))
%       {
%         s = school;
%       } else
%       {
%         s = s * opt.sep.p() * school;
%       }
%     }
%   }
%   if (empty$(year))
%   {
%     warning$("empty year in " * cite$());
%   } else
%   {
%     if (empty$(s))
%     {
%       s = year;
%     } else
%     {
%       s = comma.connect(s, year);
%     }
%   }
%   return s;
% }
FUNCTION {format.thesis.info}
{ "" 's :=
  address empty$
  school empty$
  and
  { "empty address and school in " cite$ * warning$ }
  { address empty$
    { "empty address in " cite$ * warning$ }
    { address 's := }
    if$
    school empty$
    { "empty school in " cite$ * warning$  }
    { s empty$
      { school 's := }
      { s opt.sep.p * school * 's := }
      if$
    }
    if$
  }
  if$
  year empty$
  { "empty year in " cite$ * warning$ }
  { s empty$
    { year 's := }
    { s year comma.connect 's := }
    if$
  }
  if$
  s
}

% Formatuje pocet stran a priloh u akademickych praci.
%
% string format.thesis.range ()
% {
%   if ( (empty$(format.range())) && (!empty$(inserts)) )
%   {
%     return format.range();
%   } else
%   {
%     if (is.ord(inserts))
%     {
%       return comma.connect(format.range(), inserts * " příl.");
%     } else
%     {
%       return comma.connect(format.range(), inserts);
%     }
%   }
% }
FUNCTION {format.thesis.range}
{ pages empty$
  { "" 's := }
  { pages opt.pages tie.or.connect 's := }
  if$
  s empty$
  { "" }
  { inserts empty$
    { s }
    { s inserts opt.pages tie.or.connect " příl." * comma.connect }
    if$
  }
  if$
}

% Formatuje typ akademicke prace.
%
% string format.thesis.type (string basic.thesis.type)
% {
%   if (empty$(type))
%   {
%     return basic.thesis.type;
%   } else
%   {
%     return capitalize(type);
%   }
% }
FUNCTION {format.thesis.type}
{ type empty$
  'skip$
  { pop$ type capitalize }
  if$
}

% Fromatuje typ a cislo technicke zpravy
%
% string format.report.type ()
% {
%   if (empty$(type))
%   {
%     push("");
%     warning$("type empty in "* cite$());
%   } else
%   {
%     push(type);
%   }
%   if (empty$(number))
%   {
%     warning$("number empty in "* cite$());
%   } else
%   {
%     comma.connect(pop(), number);
%   }
% }
FUNCTION {format.report.type}
{ type empty$
  { ""
    "type empty in " cite$ * warning$
  }
  { type }
  if$
  number empty$
  { "number empty in " cite$ * warning$ }
  { number comma.connect }
  if$
}

% Kontrola prazdnosti vsech policek pouzitych pro @MISC zaznam.
%
% int empty.misc.check ()
% {
%   if ( (empty$(author)) && (empty$(title)) && (empty$()) &&
%        (empty$(howpublished)) && (empty$(month)) && (empty$(year)) &&
%        (empty$(note)) && (!empty$(key)) )
%   {
%     warning$("all misc relevant fields are empty in " * cite$());
%     return 1;
%   } else
%   {
%     return 0;
%   }
% }
FUNCTION {empty.misc.check}
{ author empty$ title empty$ howpublished empty$
  month empty$ year empty$ note empty$
  and and and and and
  key empty$ not and
  { "all misc relevant fields are empty in " cite$ * warning$
    #1
  }
  { #0 }
  if$
}

% Formatuje misto a instituci technicke zpravy.
%
% string format.report.details ()
% {
%   if ( empty$(address) && empty$(institution) )
%   {
%     return "";
%   } else
%   {
%     if (empty$(address))
%     {
%       push("[b.m.]");
%     } else
%     {
%       push(address);
%     }
%     if (empty$(institution))
%     {
%       warning$("institution is empty in " * cite$());
%     } else
%     {
%       return pop() * opt.sep.p() * institution;
%     }
%   }
% }
FUNCTION {format.report.details}
{ address empty$
  institution empty$
  and
  { "" }
  { address empty$
    { "[b.m.]" }
    { address }
    if$
    institution empty$
    { "empty institution in " cite$ * warning$ }
    { opt.sep.p * institution * }
    if$
  }
  if$
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%% VLASTNI KOD -- FUNKCE PRO ZPRACOVANI ZAZNAMU %%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Zpracuje zaznamy typu @Article.
% Bibliograficke citace clanku v serialovych publikaci (casopiseckych clanku).
%
% Povinne polozky:   author, title, journal, edition, year, number, pages
% Volitelne polozky: subtitle, contrybutory, url*, month, volume, note, issn
% Polozky el. dok.:  howpublished*, revised*, cited*, version
%
% * Povinna polozka pro el. dok.
FUNCTION {article}
{ output.bibitem
  format.authors
  duplicate$ empty$
  { pop$
    "empty author in " cite$ * warning$
  }
  { output.authors }
  if$
  new.block %% primarni odpovednost (povinna)
  format.title "title" output.check
  new.block %% titul (povinny)
  contrybutory capitalize output
  new.block %% podrizena odpovednost (volitelna)
  format.journal "journal" output.check
  format.howpublished output
  new.block %% nazev serial. pub. (povinny) a druh nosice (povinny u el. dok.)
  format.edition "edition" output.check
  new.block %% vydani (povinne)
  format.journal.issue
  format.revised comma.connect
  format.cited tie.or.connect capitalize output
  new.block %% datum vydani (povinne), oznaceni cisla (povinne),
            %% datum revize/aktualizace a citace (povinne u el. dok.)
  format.pages capitalize "pages" output.check
  new.block %% lokace ve zdrojovem dokumentu (povinna)
  note output
  new.block %% poznamky (volitelne)
  howpublished empty$
  { format.url output }
  { format.url "url" output.check
    year empty$
    revised empty$
    and
    { "empty year and revised in " cite$ * warning$ }
    'skip$
    if$
  }
  if$
  new.block %% dostupnost (povinna u el. dok.)
  format.issn output
  fin.entry %% standardni cislo ISSN (volitelne)
}% @Article

% Zpracuje zaznamy typu @Book.
% Bibliograficke citace monografickych publikaci (knih).
%
% Povinne polozky:   author nebo editor, title, edition, year, isbn
% Volitelne polozky: subtitle, contrybutory, address, publisher, month,
%       pages, series, number nebo volume, note, url*
% Polozky el. dok.:  howpublished*, revised*, cited*, version
%
% * Povinna polozka pro el. dok.
FUNCTION {book}
{ output.bibitem
  author.or.editor
  new.block %% primarni odpovednost (povinna)
  format.btitle "book title" output.check
  format.howpublished output
  new.block %% nazev (povinny) a druh nosice (povinny u el. dok.)
  contrybutory capitalize output
  new.block %% podrizena odpovednost (volitelna)
  format.edition capitalize "edition" output.check
  new.block %% vydani (povinne)
  format.publish.info
  format.date comma.connect
  format.revised comma.connect
  format.cited tie.or.connect
  capitalize output
  new.block %% nakladatelske udaje (volitelne), datum vydani (povinne),
            %% datum revize/aktualizace a citace (povinne u el. dok.)
  format.range output
  new.block %% rozsah (volitelny)
  format.bvolume output
  new.block %% edice (volitelna)
  note capitalize output
  new.block %% poznamky (volitelne)
  howpublished empty$
  { format.url output }
  { format.url "url" output.check
    year empty$
    revised empty$
    and
    { "empty year and revised in " cite$ * warning$ }
    'skip$
    if$
  }
  if$
  new.block %% dostupnost (povinna u el. dok.)
  format.isbn "isbn" output.check
  fin.entry %% standardni cislo ISBN (povinne)
}% @Book

% Zpracuje zaznamy typu @Conference a @InProceedings.
% Bibliograficke citace monografickych publikaci (knih).
%
% Povinne polozky:   author, title, editor nebo organization, booktitle,
%       edition, year, pages, isbn or issn.
% Volitelne polozky: subtitle, booksubtitle, address, publisher, month, series,
%       number nebo volume, note, url*.
% Polozky el. dok.:  howpublished*, revised*, cited*, version.
%
% * Povinna polozka pro el. dok.
FUNCTION {conference}
{ output.bibitem
  format.authors
  duplicate$ empty$
  { pop$
    "empty author in " cite$ * warning$
  }
  { output.authors }
  if$
  new.block %% primarni odpovednost (povinna)
  format.title "title" output.check
  new.block %% titul prispevku
  conference.basics
  format.howpublished tie.or.connect output
  new.block %% primarni odpovednost a titul sborniku
  format.edition "edition" output.check
  new.block %% vydani
  format.publish.info
  format.date comma.connect
  format.revised comma.connect
  format.cited tie.or.connect
  capitalize output
  new.block %% nakladatelske udaje, datum vydani, revize/aktualizace a citace
  format.pages capitalize "pages" output.check
  new.block %% rozsah stran
  format.bvolume output
  new.block %% edice (pokud je cislovana, tak i jeji cislo nebo svazek)
  note capitalize output
  new.block %% poznamky
  howpublished empty$
  { format.url output }
  { format.url "url" output.check
    year empty$
    revised empty$
    and
    { "empty year and revised in " cite$ * warning$ }
    'skip$
    if$
  }
  if$
  new.block %% dostupnost (povinna u el. dok.)
  isbn empty$
  { issn empty$
    { "empty isbn or issn in " cite$ * warning$ }
    { format.issn output }
    if$
  }
  { format.isbn output }
  if$
  fin.entry %% standardni cislo ISBN nebo ISSN (povinne)
}%@Conference a @InProceedings

% @InProceedings je pouhy odkaz na @Conference.
FUNCTION {inproceedings} { conference }

% Zpracuje zaznamy typu @Misc.
% Vhodne pouziti napr. pro bibliograficke citace online dokumentu a webovych
% stranek.
%
% Povinne polozky:   Alespon jedna z volitelnych!
% Volitelne polozky: author, title, subtitle, howpublished, edition, month,
%       year, revised*, cited, note, url, version
%
% Pozn.: Protestuje, pokud neni vyplneny rok. Nemel by tedy volat format.date...
FUNCTION {misc}
{ empty.misc.check
  'skip$
  { output.bibitem
    format.authors
    duplicate$ empty$
    { pop$
      "empty author in " cite$ * warning$
    }
    { output.authors }
    if$
    new.block
    format.btitle "title" output.check
    format.howpublished output
    new.block
    format.edition output
    new.block
    format.date
    format.revised comma.connect
    format.cited tie.or.connect output
    new.block
    note capitalize output
    new.block
    howpublished empty$
    { format.url output }
    { format.url "url" output.check
      year empty$
      revised empty$
      and
      { "empty year and revised in " cite$ * warning$ }
      'skip$
      if$
    }
    if$
    fin.entry
  }
  if$
}%@Misc

% Zpracuje zaznamy typu @InBook.
% Bibliograficke citace kapitoly ci rozsahu stran v monografii.
%
% Povinne polozky:   author nebo editor, title, edition, volume, year,
%       pages a/nebo chapter
% Volitelne polozky: subtitle, contrybutory, address, publisher, month,
%       note, url*, isbn
% Polozky el. dok.:  howpublished*, revised*, cited*, version
%
% * Povinna polozka pro el. dok.
FUNCTION {inbook}
{ output.bibitem
  author.or.editor
  new.block %% primarni odpovednost (povinna)
  format.btitle "book title" output.check
  format.howpublished output
  new.block %% nazev (povinny) a druh nosice (povinny u el. dok.)
  format.edition capitalize "edition" output.check
  new.block %% vydani (povinne)
  format.vol "volume" output.check
  new.block %% urceni casti dila (povinne -- predevsim u vicesvazkovych pub.)
  contrybutory capitalize output
  new.block %% podrizena odpovednost (volitelna)
  format.publish.info
  format.date comma.connect
  format.revised comma.connect
  format.cited tie.or.connect
  capitalize output
  new.block %% nakladatelske udaje (volitelne), datum vydani (povinne),
            %% datum revize/aktualizace a citace (povinne u el. dok.)
  chapter
  format.pages comma.connect
  capitalize "chapter and/or pages" output.check
  new.block %% Lokace casti
    chapter empty$
    pages empty$
    and
    { "empty chapter and pages in " cite$ * warning$ }
    'skip$
    if$
  note capitalize output
  new.block %% poznamky (volitelne)
  howpublished empty$
  { format.url output }
  { format.url "url" output.check
    year empty$
    revised empty$
    and
    { "empty year and revised in " cite$ * warning$ }
    'skip$
    if$
  }
  if$
  new.block %% dostupnost (povinna u el. dok.)
  format.isbn output
  fin.entry %% standardni cislo (volitelne)
}%@InBook

% Zpracuje zaznamy typu @TechReport.
%
% Povinne polozky:   author, title, institution, year, type, number
% Volitelne polozky: subtitle, contrybutory, address, month, pages, note, url*
% Polozky el. dok.:  howpublished*, revised*, cited*
FUNCTION {techreport}
{ output.bibitem
  format.authors
  duplicate$ empty$
  { pop$
    "empty author in " cite$ * warning$
  }
  { output.authors }
  if$
  new.block %% primarni odpovednost (povinna)
  format.btitle "title" output.check
  format.howpublished output
  new.block
  contrybutory capitalize output
  new.block %% podrizena odpovednost (volitelna)
  format.report.details
  format.date comma.connect
  format.revised comma.connect
  format.cited tie.or.connect
  capitalize output
  new.block %% udeja o vydavajici instituci (volitelne) a datum vydani (povinne)
  format.range output
  new.block %% rozsah (volitelny)
  format.report.type capitalize output
  new.block %% typ a cislo zpravy (povinne polozky)
  note capitalize output
  new.block %% poznamka (volitelna)
  format.url output
  new.block %% dostupnost (volitelna)
  fin.entry
}%@TechReport

% Zpracuje zaznamy typu @BachelorThesis, @MasterThesis a @PhdThesis.
% Bibliograficke citace akademickych praci (bakalarske, diplomove a dizertacni).
%
% Zakladni verze -- v choose.thesis ma hodnotu #0.
%
% Povinne polozky:   author, title, address, school, year
% Volitelne polozky: subtitle, pages, inserts, type, note, url, isbn
FUNCTION {thesis}
{ output.bibitem
  format.authors
  duplicate$ empty$
  { pop$
    "empty author in " cite$ * warning$
  }
  { output.authors }
  if$
  new.block %% primarni odpovednost (povinna)
  format.btitle "title" output.check
  new.block %% titul (povinny)
  format.thesis.info capitalize output
  new.block %% misto, skola a rok {povinne)
  format.thesis.range output
  new.block %% rozsah akademicke prace a jejich priloh (volitelne)
  type$ "l" change.case$
  duplicate$ "bachelorthesis" =
  { pop$ "Bakalářská práce" }
  { "masterthesis" =
    { "Diplomová práce" }
    { "Disertační práce" }
    if$
  }
  if$
  format.thesis.type output
  new.block %% typ akademicke prace (volitelny -- pouzije se implicitni)
  note capitalize output
  new.block %% poznamky (povinne)
  format.url output
  new.block %% pristup na WWW (volitelny)
  format.isbn output
  fin.entry %% standardni cislo ISBN (volitelne)
}%@BachelorThesis, @MasterThesis a @PhdThesis

% Dalsi funkce pro vytvoreni bibliografickych citaci akademickych praci.
%
% Jina verze -- v choose.thesis ma hodnotu #1.
FUNCTION {another.thesis}
{ output.bibitem
  format.authors
  duplicate$ empty$
  { pop$
    "empty author in " cite$ * warning$
  }
  { output.authors }
  if$
  new.block %% primarni odpovednost (povinna)
  format.btitle "title" output.check
  new.block %% titul (povinny)
  type$ "l" change.case$
  duplicate$ "bachelorthesis" =
  { pop$ "Bakalářská práce" }
  { "masterthesis" =
    { "Diplomová práce" }
    { "Disertační práce" }
    if$
  }
  if$
  format.thesis.type
  school empty$
  { "empty school in " cite$ * warning$ }
  { school comma.connect }
  if$
  address empty$
  { "empty address in " cite$ * warning$ }
  { address comma.connect }
  if$
  year empty$
  { "empty year in " cite$ * warning$ }
  { year comma.connect }
  if$
  capitalize output
  new.block %% typ akademicke prace, skola, adresa, datum vydani prace.
  format.thesis.range output
  new.block %% rozsah akademicke prace
  note capitalize output
  new.block %% poznamky (povinne)
  format.url output
  new.block %% pristup na WWW (volitelny)
  format.isbn output
  fin.entry %% standardni cislo ISBN (volitelne)
}%@BachelorThesis, @MasterThesis a @PhdThesis

% Podle hodnoty volby opt.thesis vybere, ktery tvar bibliografickych citaci
% pro akademicke prace bude vyuzit.
FUNCTION {chosen.thesis}
{ opt.thesis #0 =
  { thesis }
  { another.thesis }
  if$
}

% Zaznamy typu @BachelorThesis jsou zpracovany funkci thesis.
FUNCTION {bachelorthesis}{ chosen.thesis }

% Zaznamy typu @MasterThesis jsou zpracovany funkci thesis.
FUNCTION {masterthesis} { chosen.thesis }

% Zaznamy typu @PhdThesis jsou zpracovany funkci thesis.
FUNCTION {phdthesis} { chosen.thesis }

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%% MIRNE UPRAVENE FUNKCE PREVZATE Z plain.bst %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% nacteni bibliograficke databaze
READ

% Pripravi hodnotu pro razeni -- aplikuje vestavenou funkci purify$ a prevede
% na minusky.
FUNCTION {sortify}
{ purify$
  "l" change.case$
}

% Deklarace dalsi celociselne promenne.
INTEGERS { len }

% Vrati pouze cast predane hodnoty.
FUNCTION {chop.word}
{ 's :=
  'len :=
  s #1 len substring$ =
    { s len #1 + global.max$ substring$ }
    's
  if$
}

% Piprava jmen na razeni.
FUNCTION {sort.format.names}
{ 's :=
  #1 'nameptr :=
  ""
  s num.names$ 'numnames :=
  numnames 'namesleft :=
    { namesleft #0 > }
    { nameptr #1 >
  { "   " * }
  'skip$
      if$
%       s nameptr "{vv{ } }{ll{ }}{  ff{ }}{  jj{ }}" format.name$ 't :=
      s nameptr "{ll{ }}{  ff{ }}{  vv{ }}" format.name$ 't :=  %% Zamena!
      nameptr numnames = t "others" = and
  { "et al" * }
  { t sortify * }
      if$
      nameptr #1 + 'nameptr :=
      namesleft #1 - 'namesleft :=
    }
  while$
}

% Priprava titulu na serazeni.
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

% Serazeni dle autora.
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

% Serazeni dle editora.
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

% Serazeni dle autora, editora nebo organizace. Jedna se o nevyuzitou funkci.
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

% Serazeni dle editora ci organizace. Jedna se o nevyuzitou funkci.
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

% Priprava na razeni.
%
% Funkce je zmenena oproti puvodnimu zneni v plain.bst.
FUNCTION {presort}
{ type$ "book" =
  type$ "inbook" =
  or
  { author.editor.sort }
  { author.sort }
  if$
  "    " *
  year field.or.null sortify *
  "    " *
  title field.or.null
  sort.format.title *
  #1 entry.max$ substring$
  'sort.key$ :=
}

% Provede pripravu pred razenim.
ITERATE {presort}

% Provede serazeni.
SORT

% Deklarace retezcove promenne pro urceni nejdelsiho navesti do soupisu bib.cit.
STRINGS { longest.label }

% Deklarace pomocnych ciselnych promennych.
INTEGERS { number.label longest.label.width }

% Inicializace pomocnych promennych.
FUNCTION {initialize.longest.label}
{ "" 'longest.label :=
  #1 'number.label :=
  #0 'longest.label.width :=
}

% Predani nejdelsiho navesti.
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

% Provede inicializaci pomocnych promennych.
EXECUTE {initialize.longest.label}

% Vybere nejdelsi navesti.
ITERATE {longest.label.pass}

% Tato funkce se stara o prvni radky, ktere se objevi ve vystupnim souboru.
%
% Tato funkce je rozsirena o podminenou definici prikazu \url{}.
FUNCTION {begin.bib}
{ "\makeatletter" write$ newline$
  "\@ifundefined{url}"
    "{\def\url#1{{\tt $<$#1$>$}}}" *
    "{\DeclareUrlCommand\url{\def\UrlLeft{<} \def\UrlRight{>} \urlstyle{tt}}}" *
    write$ newline$
  "\makeatother" write$ newline$
  preamble$ empty$
    'skip$
    { preamble$ write$ newline$ }
  if$
  "\begin{thebibliography}{"  longest.label  * "}" * write$ newline$
}

% Funkce zapise posledni radky do vystupniho souboru -- uzavre prostredi
% thebibliography.
FUNCTION {end.bib}
{ newline$
  "\end{thebibliography}" write$ newline$
}

% Vlozi do vystupniho souboru zacatek prostredi thebibliography.
EXECUTE {begin.bib}

% Provede inicilizaci potrebnych konstant.
EXECUTE {init.state.consts}

% Zpracovani vsech citovanych zaznamu.
ITERATE {call.type$}

% Uzavre prostredi thebibliography.
EXECUTE {end.bib}
