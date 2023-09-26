//
//  WebViewLayoutController.swift
//  desktop_webView_window
//
//  Created by Bin Yang on 2021/11/18.
//

import Cocoa
import FlutterMacOS
import WebKit
import SwiftUI

class WebViewLayoutController: NSViewController {
  private lazy var titleBarController: FlutterViewController = {
    let project = FlutterDartProject()
    project.dartEntrypointArguments = ["web_view_title_bar", "\(viewId)", "\(titleBarTopPadding)"]
    return FlutterViewController(project: project)
  }()

  private var webView: WKWebView = WKWebView()

  private var javaScriptHandlerNames: [String] = []

  weak var webViewPlugin: DesktopWebviewWindowPlugin?

  private var defaultUserAgent: String?

  private let methodChannel: FlutterMethodChannel

  private let viewId: Int64

  private let titleBarHeight: Int

  private let titleBarTopPadding: Int

  private var contentView : ContentView

    public init(methodChannel: FlutterMethodChannel, viewId: Int64, titleBarHeight: Int, titleBarTopPadding: Int) {
        self.viewId = viewId
        self.methodChannel = methodChannel
        self.titleBarHeight = titleBarHeight
        self.titleBarTopPadding = titleBarTopPadding
        self.contentView = ContentView(webView: webView);
        super.init(nibName: "WebViewLayoutController", bundle: Bundle(for: WebViewLayoutController.self))
    }


  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

    struct EmptyView: View{
        var body: some View{
            HStack{
                Spacer()
            }.frame(height: 30)
        }
    }

    struct ContentView : View {
        @State var text = "Update me!"
        @State var webView : WKWebView

        @State var isHover01 = false
        @State var isHover02 = false
        @State var isHover03 = false

        init(webView: WKWebView) {
            self.webView = webView
        }

        var body: some View {
            VStack {
                HStack {
                    Button(action:{
                        if webView.canGoBack {
                            webView.goBack()
                        }
                    }){
                        Image(systemName: "arrow.left")
                            .renderingMode(.original)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(Color(isHover01 ? .black.copy(alpha: 0.2)! : .clear))
                    .animation(.spring())
                    .onHover { hover in
                        isHover01 = hover
                    }
                    .cornerRadius(100)

                    Button(action:{
                        if webView.canGoForward {
                            webView.goForward()
                        }
                    }){
                        Image(systemName: "arrow.right")
                            .renderingMode(.original)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(Color(isHover02 ? .black.copy(alpha: 0.2)! : .clear))
                    .animation(.spring())
                    .onHover { hover in
                        isHover02 = hover
                    }
                    .cornerRadius(100)

                    Button(action:{
                        webView.reload()
                    }){
                        Image(systemName: "arrow.clockwise")
                            .renderingMode(.original)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(Color(isHover03 ? .black.copy(alpha: 0.2)! : .clear))
                    .animation(.spring())
                    .onHover { hover in
                        isHover03 = hover
                    }
                    .cornerRadius(100)


                    Spacer()
                }.padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 0))
            }
        }
    }


    override func loadView() {
      super.loadView()

      addChild(titleBarController)
      titleBarController.view.translatesAutoresizingMaskIntoConstraints = false

      // Register titlebar plugins
      ClientMessageChannelPlugin.register(with: titleBarController.registrar(forPlugin: "DesktopWebviewWindowPlugin"))

      addViews()
    }

    func addViews(){
        view.subviews.removeAll()

        let nContentView = titleBarTopPadding == 30 ? NSHostingView(rootView: EmptyView()) : NSHostingView(rootView: contentView);
        view.addSubview(nContentView)
        nContentView.translatesAutoresizingMaskIntoConstraints = false

        let constraints = [
            nContentView.topAnchor.constraint(equalTo: view.topAnchor),
            nContentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nContentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nContentView.heightAnchor.constraint(equalToConstant: CGFloat(titleBarHeight + titleBarTopPadding)),
        ]

        NSLayoutConstraint.activate(constraints)

        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: nContentView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

  override func viewDidLoad() {
    super.viewDidLoad()

    webView.navigationDelegate = self
    webView.uiDelegate = self

    // TODO(boyan01) Make it configuable from flutter.
    webView.configuration.preferences.javaEnabled = true
    webView.configuration.preferences.minimumFontSize = 12
    webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
    webView.configuration.allowsAirPlayForMediaPlayback = true
    webView.configuration.mediaTypesRequiringUserActionForPlayback = .video

    webView.addObserver(self, forKeyPath: "canGoBack", options: .new, context: nil)
    webView.addObserver(self, forKeyPath: "canGoForward", options: .new, context: nil)
    webView.addObserver(self, forKeyPath: "loading", options: .new, context: nil)

    defaultUserAgent = webView.value(forKey: "userAgent") as? String
  }

  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
    if keyPath == "canGoBack" || keyPath == "canGoForward" {
      methodChannel.invokeMethod("onHistoryChanged", arguments: [
        "id": viewId,
        "canGoBack": webView.canGoBack,
        "canGoForward": webView.canGoForward,
      ])
    } else if keyPath == "loading" {
      if webView.isLoading {
        methodChannel.invokeMethod("onNavigationStarted", arguments: [
          "id": viewId,
        ])
      } else {
        methodChannel.invokeMethod("onNavigationCompleted", arguments: [
          "id": viewId,
        ])
      }
    }
  }

  func load(url: URL) {
    debugPrint("load url: \(url)")
    webView.load(URLRequest(url: url))
  }

  func addJavascriptInterface(name: String) {
    javaScriptHandlerNames.append(name)
    webView.configuration.userContentController.add(self, name: name)
  }

  func removeJavascriptInterface(name: String) {
    if let index = javaScriptHandlerNames.firstIndex(of: name) {
      javaScriptHandlerNames.remove(at: index)
    }
    webView.configuration.userContentController.removeScriptMessageHandler(forName: name)
  }

  func addScriptToExecuteOnDocumentCreated(javaScript: String) {
    webView.configuration.userContentController.addUserScript(
      WKUserScript(source: javaScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
  }

  func setApplicationNameForUserAgent(applicationName: String) {
    webView.customUserAgent = (defaultUserAgent ?? "") + applicationName
  }

  func destroy() {
    webView.removeObserver(self, forKeyPath: "canGoBack")
    webView.removeObserver(self, forKeyPath: "canGoForward")
    webView.removeObserver(self, forKeyPath: "loading")

    webView.uiDelegate = nil
    webView.navigationDelegate = nil
    javaScriptHandlerNames.forEach { name in
      webView.configuration.userContentController.removeScriptMessageHandler(forName: name)
    }
    webView.configuration.userContentController.removeAllUserScripts()
  }

    func reload() {
        webView.reload()
    }

    func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }

    func stopLoading() {
        webView.stopLoading()
    }

    func evaluateJavaScript(javaScriptString: String, completer: @escaping FlutterResult) {
        webView.evaluateJavaScript(javaScriptString) { result, error in
            if let error = error {
                completer(FlutterError(code: "1", message: error.localizedDescription, details: nil))
                return
            }
            completer(result)
        }
    }

    func fullScreen() {
        self.view.window?.toggleFullScreen(self)
    }

    func reTitle(title: String) {
        self.view.window?.title = title
    }

    func opacity(opacity: Double) {
        self.view.window?.alphaValue = opacity
    }
}

extension WebViewLayoutController: WKNavigationDelegate {
  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    guard let url = navigationAction.request.url else {
      decisionHandler(.cancel)
      return
    }

    methodChannel.invokeMethod("onUrlRequested", arguments: [
      "id": viewId,
      "url": url.absoluteString,
    ])

    decisionHandler(.allow)
  }

  func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
          let openPanel = NSOpenPanel()
          openPanel.canChooseFiles = true
          openPanel.begin { (result) in
              if result == NSApplication.ModalResponse.OK {
                  if let url = openPanel.url {
                      completionHandler([url])
                  }
              } else if result == NSApplication.ModalResponse.cancel {
                  completionHandler(nil)
              }
          }
      }

  func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
    decisionHandler(.allow)
  }
}

extension WebViewLayoutController: WKUIDelegate {
  func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
    methodChannel.invokeMethod(
      "runJavaScriptTextInputPanelWithPrompt",
      arguments: [
        "id": viewId,
        "prompt": prompt,
        "defaultText": defaultText ?? "",
      ]) { result in
      completionHandler((result as? String) ?? "")
    }
  }

  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    if !(navigationAction.targetFrame?.isMainFrame ?? false) {
      webView.load(navigationAction.request)
    }
    return nil
  }
}

extension WebViewLayoutController: WKScriptMessageHandler {
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    methodChannel.invokeMethod(
      "onJavaScriptMessage",
      arguments: [
        "id": viewId,
        "name": message.name,
        "body": message.body,
      ])
  }
}
