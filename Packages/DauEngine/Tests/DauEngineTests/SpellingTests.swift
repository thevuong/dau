import Testing
import DauEngine

/// Group 4 — syllable spelling (D31) and stopping transforms on misspelled words (D30).
@Suite("4. Chính tả âm tiết (D30, D31)")
struct SpellingTests {
    /// D31 c/k/q, g/gh, ng/ngh distribution: misspelled words stop transforming (D30)
    /// and are restored as typed (D4).
    @Test(arguments: [
        Case("ce ", "ce "), Case("ces", "ces"), Case("cis", "cis"),
        // D31 place names: k may stand before any vowel (Kon Tum, Bắc Kạn).
        Case("ka ", "ka "), Case("kas", "ká"), Case("kis", "kí"), Case("kys", "ký"),
        Case("ghu ", "ghu "), Case("ghus", "ghus"), Case("ghis", "ghí"), Case("ghees", "ghế"),
        Case("ngi ", "ngi "), Case("ngif", "ngif"), Case("nghix", "nghĩ"),
        Case("ges", "ges"), Case("gaf", "gà"),
        Case("qa ", "qa "), Case("qas", "qas"), Case("quas", "quá"),
    ])
    func initialDistribution(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D31: "p" is an initial (pin, pa-tê).
    @Test(arguments: [Case("pin ", "pin "), Case("pins ", "pín "), Case("pa ", "pa ")])
    func initialP(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D31: stop finals p, t, c, ch take only sắc or nặng; without a tone they are not
    /// valid either. While typing only the prefix matters (D30), so the tone shows;
    /// the full rule applies at the boundary.
    @Test(arguments: [
        Case("catf", "càt"), Case("catf ", "catf "), Case("capf ", "capf "),
        Case("cacr ", "cacr "), Case("cachx ", "cachx "),
        Case("bak ", "bak "), Case("bach ", "bach "), Case("hoc ", "hoc "),
        Case("vieet ", "vieet "),  // "viêt" without a tone is not a syllable.
        Case("cats ", "cát "), Case("hocj ", "học "), Case("cachs ", "cách "),
        Case("carcs", "các"),      // tone typed before the final, changed later
    ])
    func stopFinals(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D31: ă and â do not end a syllable; D30: they are fine while typing.
    @Test(arguments: [
        Case("aw ", "aw "), Case("aa ", "aa "), Case("traw", "tră"), Case("trawngf ", "trằng "),
        Case("caan ", "cân "),
    ])
    func breveAndCircumflexNeedFinal(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D30: once the word cannot become a syllable, later keys are plain letters.
    @Test(arguments: [
        Case("Hasaki", "Hấki"), Case("windows", "ưindows"), Case("banana", "bânna"),
        Case("banana ", "banana "), Case("lazy ", "lazy "), Case("fanf", "fanf"),
        Case("jas", "jas"), Case("zas", "zas"),
    ])
    func stopTransforming(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D31: iê without an initial is written yê; yê after a consonant needs the u of
    /// uyê (or qu); c never takes oa, oă, oe, uy, uê, uâ (written qu). Misspelled forms
    /// stop transforming and are restored; the valid spellings next to them stay.
    @Test(arguments: [
        Case("ieen ", "ieen "), Case("ieeu ", "ieeu "), Case("ieens", "ieens"),
        Case("tyeen ", "tyeen "), Case("tyeens", "tyeens"),
        Case("coa ", "coa "), Case("coas", "coas"), Case("coan ", "coan "), Case("coawn ", "coawn "),
        Case("coe ", "coe "), Case("cuy ", "cuy "), Case("cuys", "cuys"), Case("cuee ", "cuee "),
        Case("cuaan ", "cuaan "),
    ])
    func misspelledRhymes(_ c: Case) { expectTyped(c.keys, c.expected) }

    @Test(arguments: [
        Case("yeen ", "yên "), Case("yeeu ", "yêu "), Case("khuyeen ", "khuyên "),
        Case("tuyeets ", "tuyết "), Case("quyeenr ", "quyển "), Case("quar ", "quả "),
        Case("quy ", "quy "), Case("hoa ", "hoa "), Case("khoer ", "khoẻ "), Case("cuar ", "của "),
        Case("cuoons ", "cuốn "), Case("cuowps ", "cướp "), Case("kieens ", "kiến "),
        Case("ia ", "ia "), Case("uyeen ", "uyên "), Case("gieets ", "giết "),
    ])
    func validCounterparts(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D31, place names: k before any vowel, the initial "kr", and final k after ă.
    @Test(arguments: [
        Case("DDawks Lawks", "Đắk Lắk"), Case("DDawks Lawks ", "Đắk Lắk "),
        Case("Bawsc Kajn ", "Bắc Kạn "), Case("Kroong Pawsc ", "Krông Pắc "),
        Case("Kow Tu ", "Kơ Tu "), Case("Kon Tum ", "Kon Tum "),
        Case("lawk ", "lawk "),   // "ăk" is a stop rhyme: without sắc/nặng it is restored
    ])
    func placeNames(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// Accepted consequences of the D31 place-name rules (measured on a 428-word list):
    /// these English words now spell a valid syllable, or start one, so Vietnamese wins
    /// (D4) or a later key counts as a double (D26).
    @Test(arguments: [
        Case("karma ", "kẩm "), Case("Kansas ", "Kâns "), Case("Kris ", "Krí "),
        Case("hawks ", "hắk "), Case("gawks ", "gắk "), Case("awkward ", "akward "),
    ])
    func placeNameSideEffects(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// Final k is not accepted elsewhere, so these stay as typed.
    @Test(arguments: [
        Case("ask ", "ask "), Case("task ", "task "), Case("desk ", "desk "), Case("hawk ", "hawk "),
        Case("back ", "back "), Case("tracks ", "tracks "), Case("squawk ", "squawk "),
        Case("Jack ", "Jack "), Case("risks ", "risks "),
    ])
    func englishWordsWithK(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D31: final k is accepted only when ă already stands before it; a later breve
    /// does not turn "ak" into "ăk", so these stay as typed.
    @Test func breveMustPrecedeFinalK() {
        expectTyped("lakws ", "lakws ")
        expectTyped("lak81 ", "lak81 ", vni)
        expectTyped("Lawks ", "Lắk ")
        expectTyped("asks ", "asks ")
        expectTyped("tasks ", "tasks ")
    }

    /// Rhyme table spot checks: valid rhymes stay, invalid clusters are restored.
    @Test(arguments: [
        Case("khuyas ", "khuýa "), Case("oangf ", "oàng "), Case("hoawcj ", "hoặc "),
        Case("ngoeos ", "ngoéo "), Case("yeeu ", "yêu "), Case("uoongs ", "uống "),
        Case("ooa ", "ooa "), Case("aoa ", "aoa "), Case("ieu ", "ieu "),
        Case("thuowr ", "thuở "), Case("huow ", "huơ "),
    ])
    func rhymes(_ c: Case) { expectTyped(c.keys, c.expected) }
}
