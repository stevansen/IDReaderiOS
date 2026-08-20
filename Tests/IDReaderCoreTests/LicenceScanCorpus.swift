import Foundation

/// Gemessene Ausgaben der Texterkennung, als Pruefkorpus.
///
/// Acht Aufnahmen von zwei Fahrerlaubnissen, mit einem Samsung S22 Ultra
/// fotografiert und von ML Kit gelesen. Das hier ist nicht erfunden und nicht
/// geglaettet: es ist wortwoertlich, was die Erkennung geliefert hat,
/// einschliesslich der zerlesenen Etiketten, der wilden Zeilenreihenfolge und der
/// Sprachaufdrucke, die als Buchstabensalat durchkommen.
///
/// **Anonymisiert.** Namen, Nummern und Datumsangaben sind ersetzt - zeichengenau
/// gleich lang und mit denselben Verwechslungen an denselben Stellen, denn genau
/// die sind der Gegenstand. Die Aufnahmen selbst zeigen echte Dokumente und
/// liegen deshalb nirgends im Repository.
///
/// Aus dem Android-Testquellsatz uebernommen, maschinell und nicht abgeschrieben:
/// die kaputten Zeichen sind der Punkt, und beim Abschreiben waeren sie das
/// Erste, was verlorengeht. Derselbe Korpus auf beiden Seiten heisst auch, dass
/// eine Aenderung am Parser hier und dort dieselbe Messlatte hat.
///
/// Die Erkennung selbst ist auf iOS eine andere (Vision statt ML Kit). Der Korpus
/// prueft deshalb den **Parser**, nicht die Erkennung - und das ist auch unter
/// Android schon so gewesen.
enum LicenceScanCorpus {

    struct Shot: Sendable {
        let name: String
        let text: String
    }

    /// Was auf den beiden Karten wirklich steht.
    ///
    /// Aus der Zusammenschau aller Aufnahmen gewonnen: was in fuenf von acht
    /// Bildern gleich gelesen wird, ist der Wert der Karte.
    struct Expected: Sendable {
        let surname: String
        let givenNames: String
        let dateOfBirth: String
        let placeOfBirth: String
        let dateOfIssue: String
        let dateOfExpiry: String
        let issuingAuthority: String
        let number: Set<String>
        let categories: String
    }

    static let cardA = Expected(
        surname: "MUSTERMANN",
        givenNames: "ANITA",
        dateOfBirth: "07.04.1968",
        placeOfBirth: "BOLZANO-BOZEN (BZ)",
        dateOfIssue: "05.03.2019",
        dateOfExpiry: "07.04.2031",
        issuingAuthority: "MIT-UCO",
        number: ["U1974B315M"],
        categories: "AM B"
    )

    /// Die Nummer der Karte B ist nicht zu entscheiden.
    ///
    /// Eine Aufnahme liest an der vierten Stelle ein B, eine andere eine 8. Die
    /// Karte fuehrt keine Pruefziffer, die das klaeren koennte - beide sind
    /// zulaessig, und der Parser darf fuer beide nicht getadelt werden.
    static let cardB = Expected(
        surname: "RAAB",
        givenNames: "SEBASTIAN",
        dateOfBirth: "02.09.1965",
        placeOfBirth: "BOLZANO-BOZEN (BZ)",
        dateOfIssue: "08.06.2015",
        dateOfExpiry: "02.09.2026",
        issuingAuthority: "MIT-UCO",
        number: ["U1X830164P", "U1XB30164P"],
        categories: "A B"
    )

    static func expected(for name: String) -> Expected {
        name.hasPrefix("A") ? cardA : cardB
    }

    static let shots: [Shot] = [
        Shot(
            name: "A1",
            text: "9. AM B\n11705\nPATENTE DI GUIDA REPUBBLICA ITALIANA\n1.\nMUSTERMANN\n2. ANITA\n07/04/68\nBOLZANO-BOZEN (BZ)\n4a. 05/03/2019 4c. MIT-UCO\n7\nG0. 07/O4/2031\n5. U19748315M\nFÜHRERSCHEIN\n1ein\nicenc\nFührersch\nauida Drivino\nconduire\nK\nVozni\nREPUBLIK ITALIEN"
        ),
        Shot(
            name: "A2",
            text: "FUHRERSCHEIN\nREPUBLIK ITALIEN\n9. AM B\ndi guida\ns Tiomána\n7.\n5. U1974B315M\nDriving Licen\nde conduire Füb\nnoSAjokorty\nConducción\n4b. 07/04/2031\nde Conduc cao Korekont\nde conducere\nRibewils\n4a. 05/03/2019 4c. MIT-UCO\nJcence Ridičs,\nFunrerschein Vaa\nNodicsky preukaz Vaia apll\norkort\ne Na\n3. 07/04/68 BOLZANO-BOZEN (BZ)\npnzja\nPatente\n2. ANITA\n1.\nMUSTERMANN\nas\nawo\nsko d\nPATENTE DI GUIDA\nREPUBBLICA ITALIANA"
        ),
        Shot(
            name: "A3",
            text: "9. AM B\nPATENTE DI GUIDA\n1.\nMUSTERMANN\n2. ANITA\n3. 07/04/68 BOLZANO-BOZEN (BZ)\n4a. 05/03/2019 4c. MIT-UCO\n40. 07/04/2031\n5. U1974B315M\n7\nREPUBBLICA 1TALIANA\nFÜHRERSCHEIN\nnce\nAuire Ridičs N\nDrivingli\nana Vodičsky n Chei\nwnongAjokort\nSi guida\ns de c\neukaz Va\nnduçao KorekoenoOo\nAe Condueeion\nKörl\nREPUBLIK ITALIEN\nente\neibewiis o len"
        ),
        Shot(
            name: "B1",
            text: "9. AB\nPATENTE DI GUIDA REPUBBLICA ITALIANE\n1. RAAB\n2\n3\nSEBASTIAN\n5.\n02/09/65\n4a. 08/06/2015 4c. MIT-UCO\n7\nBOLZANO-BOZEN (BZ)\n4b. 02/09/2026\nU1X830164P\nFÜHRERSCHEIN\ncence\nUnrersch\nstnc Aioke\nducão Kar\nConducciór\nTkort\nREPUBLIK ITALIEN"
        ),
        Shot(
            name: "B2",
            text: "PATENTE DI GUIDA\n1. RAAB\nSEBASTIAN\n4o. 02/09/2026\n7\n02/09/65 BOLZANO-BOZEN (BZ)\na 08/06/2015 4c. MIT-UCO\nU1X830164P\ntediguida Mode\noter\naModel\nentea\ndal\nla\ndeilo UE\nodel\nJEC\nello UE\nniediguia\noUEdipal\nFÜHRERSCHEIN\nuida\nMi\na\nipatentt guIcw\noatente digt\nitediauida Modellel\nente dig\nuida Mod\nent auic Modelo UEdipater\nde oUEdipatentediguida\nueloUEdipatente diguida Modelo UEdipate\n0atente dLgy0\nntediguida Modello UEG\ntediadavModelo UtOpat\nAodel\ndiauidaModell\nUbpatentediquidaModelloUEOoat\nEdipatente digLHda\naModello UEOi\npatente diguida MocelC\ntentedigue\nREPUBBLICA ITALIANA\ndaMo\nIpatet telOc dipan\npatento\nOnpuoo ap S Ede\nMOG\nente diguio\n1ode\ner\naModelo\nazeo olojonije zeynesd sopon\nogónpuo9\nSluoulug0\nOMBld A9pobue tojeze, nuooN\nUojoonpuo\nREPUBLIK ITALIEN\nOMHaLgpduk es"
        ),
        Shot(
            name: "B3",
            text: "FÜHRERSCHEIN\nREPUBLIK ITALIEN\n9. A B\n7.\nouida Driving L\n5. U1XB30164P\nuire Führe\n4b. 02/09/2026\n4a. 08/06/2015 4c. MIT-UCO\n02/09/65 BOLZANO-BOZEN (BZ)\n3.\nchein\nVaioto\n2.\nSEBASTIN\n1.\nRAAB\ndove\nPATENTE DI GUIDA REPUBBLICA ITALIANA"
        ),
        Shot(
            name: "B4",
            text: "FÜHRERSCHEIN\nREPUBLIK ITALIEN\n9. AB\ndi\n7.\n5. U1X830164P\n4b.\n02/09/2026\n4a.\n08/06/2015 4c. MIT-UCO\n3.\n02/09/65 BOLZANO-BOZEN (BZ)\n2.\nSEBASTIAN\n1.\nRAAB\nPATENTE DI GUIDA REPUBBLICA ITALIANA"
        ),
        Shot(
            name: "B5",
            text: "FÜHRERSCHEIN\nREPUBLIK ITALIEN\n9. AB\n7.\nAe\ndi ouida Driving Licence Rdk\nsTiomána Nodi iky preuk\nmosAjokorgy Vezelo\nConducão Korekort\n5. U1X830164P\n4b. 02/09/2026\nconduire Fü\nunrerschein\ne Conduccion\nynpae\n4a. 08/06/2015 4c. MIT-UCO\n3. 02/09/65 BOLZANO-80ZEN (BZ)\nhaz V\nkor\n2\nSEBASTIAN\n1.\nRAAB\nPATENTE DI GUIDA REPUBBLICA ITALIANA"
        ),
    ]
}
