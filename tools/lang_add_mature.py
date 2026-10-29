#!/usr/bin/env python3
"""One-off (0.17.0, YOUNG AND MATURE): adds the pt and es translations of the new strings to scripts/lang/lang_pt.gd and
lang_es.gd (keys already there are left alone; a changed key is renamed in place). Re-runnable."""
import json
import re

OLD_DILO = "A FATHER, open from the start: rooted on his nest beside the Brood Mother, he fertilises the eggs of his line (Spitters from her stage 2, Mist Toads from stage 3). Uprooted he walks and SPITS venom from afar (on flyers too), a strong Spitter of his own. Only one at a time."
NEW_DILO = OLD_DILO.replace("(Spitters from her stage 2", "(Vipers from the start, Spitters from her stage 2")
DILO_T = {
    "pt": ("(Cuspidores a partir do estágio 2 dela", "(Víboras desde o início, Cuspidores a partir do estágio 2 dela"),
    "es": ("(Escupidores desde su etapa 2", "(Víboras desde el principio, Escupidores desde su etapa 2"),
}

T = {
    "Vipers": ("Víboras", "Víboras"),
    "Viper": ("Víbora", "Víbora"),
    "Young Tyrant": ("Jovem Tirano", "Joven Tirano"),
    "Hooded Serpent": ("Serpente Encapuzada", "Serpiente Encapuchada"),
    "MATURE": ("AMADURECER", "MADURAR"),
    "Mature": ("Amadurecer", "Madurar"),
    "VENOM": ("VENENO", "VENENO"),
    "VENOM GLOB": ("BOLA DE VENENO", "BOLA DE VENENO"),
    "Fast venomous snakes, the Brood's first ranged unit: they spit venom at ground units only (not at flyers), shorter than a Spitter. Two hatch from each egg. Each MATURES into a Hooded Serpent once the Brood Mother is at stage 2.":
        ("Serpentes venenosas rápidas, a primeira unidade de longo alcance da Ninhada: cospem veneno só em unidades de terra (não em voadores), mais curto que um Cuspidor. Duas nascem de cada ovo. Cada uma AMADURECE numa Serpente Encapuzada quando a Mãe da Ninhada está no estágio 2.",
         "Serpientes venenosas rápidas, la primera unidad a distancia de la Camada: escupen veneno solo a unidades de tierra (no a voladores), más corto que un Escupidor. Dos nacen de cada huevo. Cada una MADURA en una Serpiente Encapuchada cuando la Madre de la Camada está en la etapa 2."),
    "A Raptor grown into a young tyrannosaur: a medium all-round biter, tougher than a Raptor, lighter and faster than a Brute. Never laid: a Raptor MATURES into it (the Brood Mother at stage 2).":
        ("Um Raptor crescido num jovem tiranossauro: um mordedor médio para tudo, mais resistente que um Raptor, mais leve e rápido que um Brutamontes. Nunca é posto: um Raptor AMADURECE nele (a Mãe da Ninhada no estágio 2).",
         "Un Raptor crecido en un joven tiranosaurio: un mordedor mediano para todo, más duro que un Raptor, más ligero y rápido que un Bruto. Nunca se pone: un Raptor MADURA en él (la Madre de la Camada en la etapa 2)."),
    "A Viper grown into a great hooded serpent: a heavy venom glob that splashes a little round its target and strips armour, nearly a Spitter's reach, at ground units only; slower than a Viper. Never laid: a Viper MATURES into it (the Brood Mother at stage 2).":
        ("Uma Víbora crescida numa grande serpente encapuzada: uma bola de veneno pesada que respinga um pouco em volta do alvo e tira armadura, quase o alcance de um Cuspidor, só em unidades de terra; mais lenta que uma Víbora. Nunca é posta: uma Víbora AMADURECE nela (a Mãe da Ninhada no estágio 2).",
         "Una Víbora crecida en una gran serpiente encapuchada: una bola de veneno pesada que salpica un poco alrededor del blanco y quita armadura, casi el alcance de un Escupidor, solo a unidades de tierra; más lenta que una Víbora. Nunca se pone: una Víbora MADURA en ella (la Madre de la Camada en la etapa 2)."),
    "Fast venomous snakes: spit at ground units only, shorter than a Spitter. Two hatch from each egg. MATURE into a Hooded Serpent.":
        ("Serpentes venenosas rápidas: cospem só em unidades de terra, mais curto que um Cuspidor. Duas nascem de cada ovo. AMADURECEM numa Serpente Encapuzada.",
         "Serpientes venenosas rápidas: escupen solo a unidades de tierra, más corto que un Escupidor. Dos nacen de cada huevo. MADURAN en una Serpiente Encapuchada."),
    "A matured Raptor: a medium all-round biter between the Raptor and the Brute.":
        ("Um Raptor amadurecido: um mordedor médio para tudo, entre o Raptor e o Brutamontes.",
         "Un Raptor madurado: un mordedor mediano para todo, entre el Raptor y el Bruto."),
    "A matured Viper: a heavy venom glob that splashes a little and strips armour, at ground units only.":
        ("Uma Víbora amadurecida: uma bola de veneno pesada que respinga um pouco e tira armadura, só em unidades de terra.",
         "Una Víbora madurada: una bola de veneno pesada que salpica un poco y quita armadura, solo a unidades de tierra."),
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
    "Its venom burns and strips 2 armour for %.1f s; ground units only.": ("Seu veneno queima e tira 2 de armadura por %.1f s; só unidades de terra.", "Su veneno quema y quita 2 de armadura durante %.1f s; solo unidades de tierra."),
    "Grows into a Hooded Serpent (the Brood Mother at stage %d).": ("Cresce numa Serpente Encapuzada (a Mãe da Ninhada no estágio %d).", "Crece en una Serpiente Encapuchada (la Madre de la Camada en la etapa %d)."),
    "In the new Brood it grows into a Young Tyrant (the Brood Mother at stage %d).": ("Na nova Ninhada cresce num Jovem Tirano (a Mãe da Ninhada no estágio %d).", "En la nueva Camada crece en un Joven Tirano (la Madre de la Camada en la etapa %d)."),
    "Strips 2 armour for %d s; half the blow splashes on enemies within %.1f tiles of its target; ground units only.": ("Tira 2 de armadura por %d s; metade do golpe respinga nos inimigos a até %.1f quadrados do alvo; só unidades de terra.", "Quita 2 de armadura durante %d s; la mitad del golpe salpica a los enemigos a %.1f casillas o menos del blanco; solo unidades de tierra."),
}


def q(s):
    return json.dumps(s, ensure_ascii=False)


for code, idx in (("pt", 0), ("es", 1)):
    p = f"scripts/lang/lang_{code}.gd"
    src = open(p).read()
    # the Venom Sire's text changed: its key and translation renamed in place
    old_line_key = q(OLD_DILO) + ":"
    if old_line_key in src:
        i = src.index(old_line_key)
        j = src.index("\n", i)
        line = src[i:j]
        a, b = DILO_T[code]
        line = line.replace(q(OLD_DILO), q(NEW_DILO), 1).replace(a, b, 1)
        src = src[:i] + line + src[j:]
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
