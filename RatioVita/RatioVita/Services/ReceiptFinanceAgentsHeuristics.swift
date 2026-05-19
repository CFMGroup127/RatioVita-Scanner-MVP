import Foundation

/// Keyword-driven suggestions for the Tax / GL agent personas (MVP before learned models).
enum ReceiptFinanceAgentsHeuristics {
    static func suggestTaxCategory(fromCorpus corpus: String) -> String? {
        if let rd = TaxCategoryCatalog.suggestFromCorpus(corpus) { return rd }
        let c = corpus.lowercased()
        if c.contains("costume") || c.contains("wardrobe") || c.contains("tailor") {
            return "Costumes_Wardrobe"
        }
        if c.contains("craft") || c.contains("cater") || c.contains("meal") || c.contains("lunch") {
            return "CraftServices_Catering"
        }
        if c.contains("hst") || c.contains("gst") || c.contains("g/hst") || c.contains("sales tax") {
            return "SalesTax_HST_GST"
        }
        if c.contains("payroll") || c.contains("net pay") || c.contains("gross pay") || c.contains("cheque") || c
            .contains("check")
        {
            return "Payroll_Income"
        }
        if c.contains("equipment") || c.contains("rental") || c.contains("grip") || c.contains("electric") {
            return "Equipment_Production"
        }
        if c.contains("vehicle") || c.contains("mileage") || c.contains("fuel") || c.contains("parking") {
            return "Vehicle_Transport"
        }
        return nil
    }

    static func suggestGLCode(fromCorpus corpus: String) -> String? {
        let c = corpus.lowercased()
        if c.contains("costume") || c.contains("wardrobe") { return "GL-5200-COSTUME" }
        if c.contains("craft") || c.contains("cater") { return "GL-5210-CRAFT" }
        if c.contains("hst") || c.contains("gst") { return "GL-2300-TAX" }
        if c.contains("equipment") || c.contains("rental") { return "GL-5400-EQUIP" }
        if c.contains("vehicle") || c.contains("fuel") || c.contains("parking") { return "GL-5500-TRANSPORT" }
        if c.contains("payroll") || c.contains("labour") || c.contains("labor") { return "GL-6100-PAYROLL" }
        return nil
    }
}
