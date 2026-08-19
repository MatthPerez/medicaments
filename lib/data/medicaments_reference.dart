/// Référentiel indicatif de molécules courantes, organisées par classe,
/// pour pré-remplir le champ "classe" à la saisie. Liste non exhaustive
/// et non validée cliniquement — sert uniquement à accélérer la saisie.
/// L'utilisateur reste libre de saisir un nom hors liste.
class MedicamentsReference {
  static const Map<String, List<String>> parClasse = {
    'Benzodiazépine': [
      'Alprazolam (Xanax)',
      'Bromazépam (Lexomil)',
      'Clonazépam (Rivotril)',
      'Clorazépate (Tranxène)',
      'Diazépam (Valium)',
      'Lorazépam (Temesta)',
      'Loprazolam (Havlane)',
      'Lormétazépam (Noctamide)',
      'Nordazépam (Nordaz)',
      'Oxazépam (Séresta)',
      'Prazépam (Lysanxia)',
      'Témazépam (Normison)',
      'Nitrazépam (Mogadon)',
    ],
    'Anxiolytique non-benzodiazépinique': [
      'Buspirone (Buspar)',
      'Hydroxyzine (Atarax)',
      'Étifoxine (Stresam)',
      'Captodiame (Covatine)',
    ],
    'Hypnotique / Z-drug': [
      'Zolpidem (Stilnox)',
      'Zopiclone (Imovane)',
      'Zaleplon (Sonata)',
    ],
    'Antidépresseur ISRS': [
      'Fluoxétine (Prozac)',
      'Paroxétine (Deroxat)',
      'Sertraline (Zoloft)',
      'Citalopram (Seropram)',
      'Escitalopram (Seroplex)',
      'Fluvoxamine (Floxyfral)',
    ],
    'Antidépresseur IRSNA': [
      'Venlafaxine (Effexor)',
      'Duloxétine (Cymbalta)',
      'Milnacipran (Ixel)',
      'Desvenlafaxine (Pristiq)',
    ],
    'Antidépresseur tricyclique': [
      'Amitriptyline (Laroxyl)',
      'Clomipramine (Anafranil)',
      'Imipramine (Tofranil)',
      'Doxépine (Quitaxon)',
      'Maprotiline (Ludiomil)',
    ],
    'Antidépresseur autre': [
      'Mirtazapine (Norset)',
      'Miansérine (Athymil)',
      'Tianeptine (Stablon)',
      'Agomélatine (Valdoxan)',
      'Bupropion (Zyban)',
      'Vortioxétine (Brintellix)',
    ],
    'Antiépileptique / Thymorégulateur': [
      'Valproate de sodium (Dépakine)',
      'Carbamazépine (Tégrétol)',
      'Lamotrigine (Lamictal)',
      'Gabapentine (Neurontin)',
      'Prégabaline (Lyrica)',
      'Lévétiracétam (Keppra)',
      'Topiramate (Epitomax)',
      'Oxcarbazépine (Trileptal)',
      'Lithium (Téralithe)',
    ],
    'Antipsychotique / Neuroleptique': [
      'Rispéridone (Risperdal)',
      'Olanzapine (Zyprexa)',
      'Quétiapine (Xeroquel)',
      'Aripiprazole (Abilify)',
      'Halopéridol (Haldol)',
      'Cyamémazine (Tercian)',
      'Lévomépromazine (Nozinan)',
      'Loxapine (Loxapac)',
    ],
    'Opioïde antalgique': [
      'Tramadol',
      'Codéine',
      'Morphine',
      'Oxycodone',
      'Fentanyl',
    ],
  };

  /// Retourne la classe associée à un nom, si trouvé dans le référentiel.
  static String? classePour(String nom) {
    for (final entry in parClasse.entries) {
      if (entry.value.contains(nom)) return entry.key;
    }
    return null;
  }
}
