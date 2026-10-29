#!/usr/bin/env python3
"""One-off (0.17.0, YOUNG AND MATURE): adds the pt and es translations of the new strings to scripts/lang/lang_pt.gd and
lang_es.gd (keys already there are left alone), and renames in place the texts that changed (the Venom Sire's line: the
Spitter from stage 1, the owner 14:40; the codex's NEW BROOD paragraph), in the English source (main.gd, defs.gd) and in
both tables' keys and translations. Re-runnable: a change already made is skipped."""
import json
import re


def q(s):
    return json.dumps(s, ensure_ascii=False)


# (file-independent) English substring -> new, and per language the translation's substring -> new
EDITS = [
    ("(Spitters from her stage 2, Mist Toads from stage 3)", "(Spitters from the start, Mist Toads from her stage 3)",
     {"pt": ("(Cuspidores a partir do estágio 2 dela, Sapos da Névoa a partir do estágio 3)", "(Cuspidores desde o início, Sapos da Névoa a partir do estágio 3 dela)"),
      "es": ("(Escupidores desde su etapa 2, Sapos de la Niebla desde la etapa 3)", "(Escupidores desde el principio, Sapos de la Niebla desde su etapa 3)")}),
    ("the Venom Sire: Spitters at her stage 2, Mist Toads at stage 3;", "the Venom Sire: Spitters, and Mist Toads at her stage 3;",
     {"pt": ("Sire do Veneno: Cuspidores no estágio 2 dela, Sapos da Névoa no estágio 3;", "Sire do Veneno: Cuspidores, e Sapos da Névoa no estágio 3 dela;"),
      "es": ("Señor del Veneno: Escupidores en su etapa 2, Sapos de la Niebla en la etapa 3;", "Señor del Veneno: Escupidores, y Sapos de la Niebla en su etapa 3;")}),
    ("GROW her, rooted, for more eggs and faster laying.", "GROW her, rooted, for more eggs and faster laying. From her stage 2 a young warrior MATURES into a Challenger, a young Sire (MATURE on its card: a Raptor into a Tyrant Challenger, a Spitter into a Venom Challenger).",
     {"pt": ("Faça-a CRESCER, enraizada, para mais ovos e postura mais rápida.", "Faça-a CRESCER, enraizada, para mais ovos e postura mais rápida. A partir do estágio 2 dela, um guerreiro jovem AMADURECE num Desafiante, um Sire jovem (AMADURECER no seu cartão: um Raptor num Desafiante Tirano, um Cuspidor num Desafiante Venenoso)."),
      "es": ("Hazla CRECER, arraigada, para más huevos y una puesta más rápida.", "Hazla CRECER, arraigada, para más huevos y una puesta más rápida. Desde su etapa 2 un guerrero joven MADURA en un Retador, un Señor joven (MADURAR en su tarjeta: un Raptor en un Retador Tirano, un Escupidor en un Retador Venenoso).")}),
]

T = {
    "Tyrant Challenger": ("Desafiante Tirano", "Retador Tirano"),
    "Venom Challenger": ("Desafiante Venenoso", "Retador Venenoso"),
    "MATURE": ("AMADURECER", "MADURAR"),
    "Mature": ("Amadurecer", "Madurar"),
    "VENOM": ("VENENO", "VENENO"),
    "A Raptor grown into a young Tyrant Sire: a medium all-round biter, tougher than a Raptor, lighter and faster than a Brute. Never laid: a Raptor MATURES into it (the Brood Mother at stage 2).":
        ("Um Raptor crescido num Sire Tirano jovem: um mordedor médio para tudo, mais resistente que um Raptor, mais leve e rápido que um Brutamontes. Nunca é posto: um Raptor AMADURECE nele (a Mãe da Ninhada no estágio 2).",
         "Un Raptor crecido en un Señor Tirano joven: un mordedor mediano para todo, más duro que un Raptor, más ligero y rápido que un Bruto. Nunca se pone: un Raptor MADURA en él (la Madre de la Camada en la etapa 2)."),
    "A Spitter grown into a young Venom Sire: a heavier venom glob than a Spitter's, a little farther, that strips armour and splashes a little round its target; it reaches flyers too. Tougher and slower than a Spitter. Never laid: a Spitter MATURES into it (the Brood Mother at stage 2).":
        ("Um Cuspidor crescido num Sire do Veneno jovem: uma bola de veneno mais pesada que a de um Cuspidor, um pouco mais longe, que tira armadura e respinga um pouco em volta do alvo; alcança voadores também. Mais resistente e mais lento que um Cuspidor. Nunca é posto: um Cuspidor AMADURECE nele (a Mãe da Ninhada no estágio 2).",
         "Un Escupidor crecido en un Señor del Veneno joven: una bola de veneno más pesada que la de un Escupidor, un poco más lejos, que quita armadura y salpica un poco alrededor del blanco; alcanza también a los voladores. Más duro y más lento que un Escupidor. Nunca se pone: un Escupidor MADURA en él (la Madre de la Camada en la etapa 2)."),
    "A matured Raptor, a young Tyrant Sire: a medium all-round biter between the Raptor and the Brute.":
        ("Um Raptor amadurecido, um Sire Tirano jovem: um mordedor médio para tudo, entre o Raptor e o Brutamontes.",
         "Un Raptor madurado, un Señor Tirano joven: un mordedor mediano para todo, entre el Raptor y el Bruto."),
    "A matured Spitter, a young Venom Sire: a heavier glob than a Spitter's, a little farther, with a small splash.":
        ("Um Cuspidor amadurecido, um Sire do Veneno jovem: uma bola mais pesada que a de um Cuspidor, um pouco mais longe, com um pequeno respingo.",
         "Un Escupidor madurado, un Señor del Veneno joven: una bola más pesada que la de un Escupidor, un poco más lejos, con una pequeña salpicadura."),
    "Each young unit selected grows into its mature form, one into one, as far as the food allows: it pays the mature form's price less its own share of its egg, moults %d s where it stands (it cannot move or fight), then it is the mature unit, its veterancy and wounds kept. Needs the Brood Mother at the mature form's stage.":
        ("Cada unidade jovem selecionada cresce na sua forma madura, uma para uma, até onde a comida der: paga o preço da forma madura menos a sua parte do seu ovo, faz a muda %d s onde está (não pode se mover nem lutar), e então é a unidade madura, com sua veterania e ferimentos mantidos. Precisa da Mãe da Ninhada no estágio da forma madura.",
         "Cada unidad joven seleccionada crece en su forma madura, una por una, hasta donde alcance la comida: paga el precio de la forma madura menos su parte de su huevo, muda %d s donde está (no puede moverse ni luchar), y entonces es la unidad madura, con su veteranía y heridas conservadas. Necesita a la Madre de la Camada en la etapa de la forma madura."),
    "%s into a %s: %s": ("%s em %s: %s", "%s en %s: %s"),
    "They are all moulting.": ("Todos estão em muda.", "Todos están mudando."),
    "MOULTING into a %s: %d s left (it cannot move or fight).": ("EM MUDA para %s: faltam %d s (não pode se mover nem lutar).", "MUDANDO a %s: faltan %d s (no puede moverse ni luchar)."),
    "Nothing to mature.": ("Nada para amadurecer.", "Nada que madurar."),
    "It has no mature form.": ("Não tem forma madura.", "No tiene forma madura."),
    "It is already moulting.": ("Já está em muda.", "Ya está mudando."),
    "It is held fast.": ("Está preso.", "Está atrapado."),
    "Nothing selected can mature.": ("Nada do que está selecionado pode amadurecer.", "Nada de lo seleccionado puede madurar."),
    "A %s has matured.": ("Um %s amadureceu.", "Un %s ha madurado."),
    "(MATURE a %s)": ("(AMADURECER um %s)", "(MADURAR un %s)"),
    "Its venom strips 2 armour for %.1f s; ground units only.": ("Seu veneno tira 2 de armadura por %.1f s; só unidades de terra.", "Su veneno quita 2 de armadura durante %.1f s; solo unidades de tierra."),
    "Its venom strips 2 armour for %.1f s.": ("Seu veneno tira 2 de armadura por %.1f s.", "Su veneno quita 2 de armadura durante %.1f s."),
    "Half the blow splashes on enemies within %.1f tiles of its target.": ("Metade do golpe respinga nos inimigos a até %.1f quadrados do alvo.", "La mitad del golpe salpica a los enemigos a %.1f casillas o menos del blanco."),
    "In the new Brood it grows into a %s (the Brood Mother at stage %d).": ("Na nova Ninhada cresce num %s (a Mãe da Ninhada no estágio %d).", "En la nueva Camada crece en un %s (la Madre de la Camada en la etapa %d)."),
}

for p in ["scripts/main.gd", "scripts/defs.gd"]:
    s = open(p).read()
    for old, new, _ in EDITS:
        if old in s and new not in s:
            s = s.replace(old, new)
    open(p, "w").write(s)

for code, idx in (("pt", 0), ("es", 1)):
    p = f"scripts/lang/lang_{code}.gd"
    src = open(p).read()
    for old, new, tr in EDITS:
        a, b = tr[code]
        out = []
        for line in src.split("\n"):
            m = re.match(r'^(\t)("(?:[^"\\]|\\.)*")(\s*:\s*)(.*)$', line)
            if m and old in json.loads(m.group(2)) and new not in json.loads(m.group(2)):
                k = json.loads(m.group(2)).replace(old, new)
                v = m.group(4)
                v = v.replace(a, b, 1) if a in v else v
                line = m.group(1) + q(k) + m.group(3) + v
            out.append(line)
        src = "\n".join(out)
    keys = set(m.group(1) for m in re.finditer(r'^\t("(?:[^"\\]|\\.)*")\s*:', src, re.M))
    add = []
    for k, v in T.items():
        if q(k) in keys:
            continue
        add.append(f"\t{q(k)}: {q(v[idx])},\n")
    end = src.rstrip().rfind("}")
    src = src[:end] + "".join(add) + src[end:]
    open(p, "w").write(src)
    print(code, "added", len(add))
