import AppKit
import WebKit

/// Renders a canvas artboard (`<name>.dc.html`) with WebKit, off screen. The artboards
/// load a `support.js` runtime that is not part of the export; a small shim stands in
/// for it: it evaluates the artboard's `Component.renderVals()` with the default props,
/// fills the `{{…}}` placeholders and moves the `<helmet>` styles into the head.
@MainActor
final class Mockup: NSObject, WKNavigationDelegate {
    static let shim = """
    class DCLogic { constructor(props) { this.props = props || {}; this.state = {}; }
      setState(s) { Object.assign(this.state, s); } }
    window.addEventListener('DOMContentLoaded', () => {
      const sc = document.querySelector('script[type="text/x-dc"]');
      let vals = {};
      if (sc) {
        const props = JSON.parse(sc.dataset.props || '{}'); const defaults = {};
        for (const k in props) { if (props[k] && 'default' in props[k]) defaults[k] = props[k].default; }
        const C = new Function('DCLogic', sc.textContent + '; return Component;')(DCLogic);
        vals = new C(defaults).renderVals();
      }
      const root = document.querySelector('x-dc');
      root.innerHTML = root.innerHTML.replace(/\\{\\{(\\w+)\\}\\}/g,
        (m, k) => (typeof vals[k] === 'function' || vals[k] === undefined) ? '' : String(vals[k]));
      document.querySelectorAll('helmet').forEach(h => { document.head.append(...h.children); h.remove(); });
      document.body.dataset.ready = '1';
    });
    """

    struct Rendered {
        let image: NSBitmapImageRep
        /// Element frames in window points (origin at the artboard window's top-left).
        let frames: [String: CGRect]
    }

    private var finished = false
    private let webView: WKWebView
    private let window: NSWindow

    private init(size: CGSize) {
        webView = WKWebView(frame: CGRect(origin: .zero, size: size))
        window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -9000, y: -9000), size: size),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        super.init()
        window.contentView = webView
        webView.navigationDelegate = self
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated { finished = true }
    }

    /// - Parameters:
    ///   - artboard: path of the `.dc.html` file.
    ///   - size: artboard size (`$preview`), e.g. 900×680.
    ///   - crop: the part to keep, in artboard points (the window is at 40,40).
    ///   - measure: JS expressions returning a DOMRect, by name.
    static func render(_ artboard: URL, size: CGSize, crop requested: CGRect,
                       measure: [String: String]) -> Rendered? {
        // An empty crop keeps the whole artboard (frames then use artboard coordinates).
        let crop = requested.isEmpty ? CGRect(origin: .zero, size: size) : requested
        guard var html = try? String(contentsOf: artboard, encoding: .utf8) else { return nil }
        html = html.replacingOccurrences(of: "<script src=\"./support.js\"></script>",
                                         with: "<script>\(shim)</script>")
        let mock = Mockup(size: size)
        mock.window.orderFrontRegardless()
        mock.webView.loadHTMLString(html, baseURL: artboard.deletingLastPathComponent())
        let deadline = Date().addingTimeInterval(10)
        while !mock.finished && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))   // fonts and layout

        var frames: [String: CGRect] = [:]
        for (name, expression) in measure {
            var done = false
            mock.webView.evaluateJavaScript(
                "(() => { const r = (\(expression)); return r ? [r.x, r.y, r.width, r.height] : null; })()"
            ) { value, _ in
                if let v = value as? [Double], v.count == 4 {
                    frames[name] = CGRect(x: v[0] - crop.minX, y: v[1] - crop.minY, width: v[2], height: v[3])
                }
                done = true
            }
            while !done { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
        }

        var image: NSImage?
        let config = WKSnapshotConfiguration()
        config.rect = crop
        config.snapshotWidth = NSNumber(value: Double(crop.width))
        var done = false
        mock.webView.takeSnapshot(with: config) { result, _ in image = result; done = true }
        while !done { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
        mock.window.orderOut(nil)
        guard let image else { return nil }
        // @2x bitmap of the cropped window.
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(crop.width * 2),
                                   pixelsHigh: Int(crop.height * 2), bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = crop.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: CGRect(origin: .zero, size: crop.size))
        NSGraphicsContext.restoreGraphicsState()
        return Rendered(image: rep, frames: frames)
    }
}
