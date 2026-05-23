import LinkKit
import SwiftUI
import UIKit

struct PlaidLinkView: UIViewControllerRepresentable {
    let linkToken: String
    let onSuccess: (String) -> Void
    let onExit: (Error?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSuccess: onSuccess, onExit: onExit)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()

        var configuration = LinkTokenConfiguration(token: linkToken) { success in
            context.coordinator.onSuccess(success.publicToken)
        }

        configuration.onExit = { exit in
            context.coordinator.onExit(exit.error)
        }

        let result = Plaid.create(configuration)
        switch result {
        case let .failure(error):
            DispatchQueue.main.async {
                context.coordinator.onExit(error)
            }
        case let .success(handler):
            context.coordinator.handler = handler
            DispatchQueue.main.async {
                handler.open(presentUsing: .viewController(viewController))
            }
        }

        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator {
        let onSuccess: (String) -> Void
        let onExit: (Error?) -> Void
        var handler: Handler?

        init(onSuccess: @escaping (String) -> Void, onExit: @escaping (Error?) -> Void) {
            self.onSuccess = onSuccess
            self.onExit = onExit
        }
    }
}
