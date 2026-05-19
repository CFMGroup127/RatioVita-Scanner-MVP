import Foundation

#if canImport(MessageUI)
import MessageUI
#endif

#if os(macOS)
import AppKit
#endif

#if os(iOS)
import UIKit
#endif

enum ReceiptSelectionMailer {
    /// Presents a native compose UI with a CSV summary attachment (works well for AR/AP handoff).
    @MainActor
    static func presentEmailComposer(for receipts: [Receipt]) {
        guard !receipts.isEmpty else {
            UserMessageCenter.shared.present(
                title: "Nothing to email",
                message: "Select at least one receipt, then try again."
            )
            return
        }

        do {
            let url = try ReceiptBatchExport.makeCSV(receipts: receipts)
            #if os(iOS)
            if MFMailComposeViewController.canSendMail() {
                EmailComposePresenter.shared.present(url: url, subject: mailSubject(count: receipts.count))
            } else {
                UserMessageCenter.shared.present(
                    title: "Mail not configured",
                    message: "Add a Mail account in Settings, or export and share the file manually."
                )
            }
            #elseif os(macOS)
            if let service = NSSharingService(named: .composeEmail) {
                service.subject = mailSubject(count: receipts.count)
                service.perform(withItems: [url])
            } else {
                UserMessageCenter.shared.present(
                    title: "Mail not available",
                    message: "Could not open the system email composer."
                )
            }
            #else
            UserMessageCenter.shared.present(
                title: "Email",
                message: "Email export is not available on this platform."
            )
            #endif
        } catch {
            UserMessageCenter.shared.present(
                title: "Couldn't prepare email",
                message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }
    }

    private static func mailSubject(count: Int) -> String {
        "RatioVita — \(count) receipt\(count == 1 ? "" : "s")"
    }
}

#if os(iOS)
@MainActor
final class EmailComposePresenter: NSObject, MFMailComposeViewControllerDelegate {
    static let shared = EmailComposePresenter()

    override private init() {
        super.init()
    }

    func present(url: URL, subject: String) {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = self
        vc.setSubject(subject)
        if let data = try? Data(contentsOf: url) {
            vc.addAttachmentData(data, mimeType: "text/csv", fileName: url.lastPathComponent)
        }

        guard
            let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? scene.windows.first?.rootViewController else
        {
            UserMessageCenter.shared.present(
                title: "Email",
                message: "Could not find a window to present the mail composer."
            )
            return
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        top.present(vc, animated: true)
    }

    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith _: MFMailComposeResult,
        error _: Error?
    ) {
        controller.dismiss(animated: true)
    }
}
#endif
