//
//  AlertTask.swift
//  AsyncTaskKitTests
//
//  Created by Michal Zaborowski on 2022-01-02.
//

import UIKit

// MARK: - AlertTask

@MainActor
public final class AlertTask: TaskRunnable {

    // MARK: AlertTask (Public Properties)

    public let title: String?
    public let message: String?
    public let style: UIAlertController.Style
    public let tintColor: UIColor?
    public let presentationContext: UIViewController?

    // MARK: AlertTask (Private Properties)

    private let alertController: AlertViewController

    private var continuation: CheckedContinuation<Void, Never>?

    // MARK: AlertTask (Public Methods)

    public static func alert(title: String? = nil,
                             message: String? = nil,
                             style: UIAlertController.Style = .alert,
                             actions: [Action],
                             tintColor: UIColor? = nil,
                             presentationContext: UIViewController?,
                             sourceView: UIView? = nil) -> MutuallyExclusiveTask<AlertTask> {
        let alert = AlertTask.init(title: title,
                                   message: message,
                                   style: style,
                                   tintColor: tintColor,
                                   presentationContext: presentationContext,
                                   sourceView: sourceView)

        for action in actions {
            alert.add(action: action)
        }

        return alert.mutuallyExclusive()
    }

    public init(title: String? = nil,
                 message: String? = nil,
                 style: UIAlertController.Style = .alert,
                 tintColor: UIColor? = nil,
                 presentationContext: UIViewController?,
                 sourceView: UIView? = nil
    ) {
        self.title = title
        self.message = message
        self.style = style
        self.tintColor = tintColor
        self.presentationContext = presentationContext
        self.alertController = AlertViewController(title: title, message: message, preferredStyle: style)
        if let sourceView = sourceView {
            self.alertController.popoverPresentationController?.sourceView = sourceView
            self.alertController.popoverPresentationController?.sourceRect = sourceView.bounds
        }

        alertController.didDisappearBlock = { [weak self] in
            self?.finish()
        }
    }

    public func cancel() async {
        if alertController.presentingViewController != nil {
            alertController.dismiss(animated: true) {
                self.finish()
            }
        } else {
            finish()
        }
    }

    public func run() async throws -> Void {
        if self.alertController.actions.isEmpty {
            self.addAction(with: "OK", handler: nil)
        }

        let presentationContext: UIViewController? = {
            if let context = self.presentationContext {
                return context
            }
            // When we do not have presentationContext, lets take keyWindow and its topMostViewController
            let keyWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })
            return keyWindow?.rootViewController?.topMostPresentedViewController
        }()

        assert(presentationContext != nil, "Something went wrong here, we don't have any keyWindow and presentationContext")

        if let presentationContext = presentationContext {
            return await withCheckedContinuation { continuation in

                // If presentation on context failed because of some reason, wrong presentationContext (completion handler then is not called), we must finish operation to unblock mutually exclusive alert queue
                let presentationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] timer in
                    timer.invalidate()
                    self?.finish()
                }

                presentationContext.present(self.alertController, animated: true) {
                    presentationTimer.invalidate()
                }

                if let tintColor = self.tintColor {
                    self.alertController.view.tintColor = tintColor
                }

                self.continuation = continuation
            }
        }
    }

    public func addAction(with title: String, style: UIAlertAction.Style = .default, tintColor: UIColor? = nil, handler: (() -> Void)? = nil) {
        add(action: Action(title: title, style: style, handler: handler), tintColor: tintColor)
    }

    public func add(action: Action, tintColor: UIColor? = nil) {
        let alertAction = UIAlertAction(title: action.title, style: action.style, handler: { [weak self] _ in
            action.handler?()
            self?.finish()
        })
        if let tintColor = tintColor {
            alertAction.setValue(tintColor, forKey: "title\("Text")Color")
        }
        alertController.addAction(alertAction)
    }

    // MARK: AlertTask (Private Methods)

    private func finish() {
        continuation?.resume()
        continuation = nil
    }
}

// MARK: AlertTask > Action

extension AlertTask {
    public final class Action {
        public private(set) var title: String?
        public private(set) var style: UIAlertAction.Style
        public private(set) var handler: (() -> Void)?

        public init(title: String?, style: UIAlertAction.Style, handler: (() -> Void)? = nil) {
            self.title = title
            self.style = style
            self.handler = handler
        }
    }
}

// MARK: - AlertViewController

private class AlertViewController: UIAlertController {

    // MARK: UIViewController

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        didDisappearBlock?()
    }

    // MARK: AlertOnWindowViewController (Public Properties)

    public var didDisappearBlock: (() -> Void)?
}

// MARK: - UIViewController

extension UIViewController {

    fileprivate var topMostPresentedViewController: UIViewController {
        if let presentedViewController = presentedViewController {
            return presentedViewController.topMostPresentedViewController
        } else if let parent = parent {
            return parent.topMostPresentedViewController
        }
        return self
    }
}
