import SwiftSyntax

// One syntactic occurrence of interest.
struct Occurrence: Encodable {
    var sym: String        // symbol name (member, attribute, type, macro, keypath)
    var kind: String       // modifier | member | type | attribute | macro | keypath
    var line: Int
    var col: Int
    var endLine: Int? = nil // for calls: line of the closing ) of the arg list (pre trailing-closure)
    var implicit: Bool?    // leading-dot implicit member/call (.bordered / .system(...))
    var args: [String]?    // modifier arg labels, or attribute argument text
    var trailingClosure: Bool?
    var attach: String?    // attribute target: var | let | struct | class | enum | actor | func | extension
    var prop: PropInfo?    // for attribute on a binding: the wrapped property
    var scope: String?     // enclosing type/extension name (nil = file scope)
    var src: String        // trimmed source line (≤200 chars)
}

struct PropInfo: Encodable {
    var name: String?
    var type: String?
    var initText: String?
}

// A custom component declaration (View/App/Scene/ViewModifier/Style/Shape/bridge/…).
struct Decl: Encodable {
    var name: String
    var kind: String          // view | app | scene | viewmodifier | style | shape | preview |
                              // commands | toolbarcontent | bridge | layout | transferable | viewbuilder
    var conforms: [String]
    var line: Int
    var attributes: [String]
    var wrappers: [String]
    var scope: String?        // enclosing type (for nested decls)
    var via: String?          // "extension" when conformance came from an extension
}

final class ScanVisitor: SyntaxVisitor {
    let conv: SourceLocationConverter
    let lines: [String]
    var occurrences: [Occurrence] = []
    var decls: [Decl] = []
    var imports: Set<String> = []
    var stack: [String] = []                 // enclosing type/extension names

    static let conformanceKind: [String: String] = [
        "View": "view", "App": "app", "Scene": "scene",
        "ViewModifier": "viewmodifier", "PreviewProvider": "preview",
        "Shape": "shape", "InsettableShape": "shape", "Commands": "commands",
        "ToolbarContent": "toolbarcontent", "CustomizableToolbarContent": "toolbarcontent",
        "NSViewRepresentable": "bridge", "NSViewControllerRepresentable": "bridge",
        "UIViewRepresentable": "bridge", "UIViewControllerRepresentable": "bridge",
        "Layout": "layout", "Transferable": "transferable",
    ]
    static let viewReturns = ["some View", "some Scene", "some Commands", "some ToolbarContent"]

    init(_ conv: SourceLocationConverter, _ lines: [String]) {
        self.conv = conv; self.lines = lines
        super.init(viewMode: .sourceAccurate)
    }

    private func loc(_ node: some SyntaxProtocol) -> (Int, Int) {
        let l = node.startLocation(converter: conv); return (l.line, l.column)
    }
    private func srcLine(_ line: Int) -> String {
        guard line >= 1, line <= lines.count else { return "" }
        var s = lines[line-1].trimmingCharacters(in: .whitespaces)
        if s.count > 200 { s = String(s.prefix(200)) }
        return s
    }
    /// The full call "head": `prefix(args)` with the trailing-closure body excluded, whitespace
    /// collapsed to single spaces, capped — so a multi-line call yields a complete one-line snippet.
    private func callHead(_ prefix: String, _ call: FunctionCallExprSyntax) -> String {
        var s = prefix
        if call.leftParen != nil { s += "(" + call.arguments.trimmedDescription + ")" }
        else if call.trailingClosure != nil { s += " { … }" }
        s = s.replacingOccurrences(of: "\n", with: " ")
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        s = s.trimmingCharacters(in: .whitespaces)
        if s.count > 240 { s = String(s.prefix(240)) }
        return s
    }
    private func callEndLine(_ call: FunctionCallExprSyntax) -> Int {
        if let rp = call.rightParen { return rp.endLocation(converter: conv).line }
        return call.calledExpression.endLocation(converter: conv).line
    }
    private var scope: String? { stack.last }
    private func baseName(_ s: String) -> String {
        let noGeneric = s.split(separator: "<").first.map(String.init) ?? s
        return noGeneric.split(separator: ".").last.map(String.init) ?? noGeneric
    }

    // MARK: imports
    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        if let first = node.path.first { imports.insert(first.name.text) }
        return .visitChildren
    }

    // MARK: member access (.modifier(...) or bare .member)
    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        let name = node.declName.baseName.text
        guard !name.isEmpty, name != "self", name != "init" else { return .visitChildren }
        let (ln, col) = loc(node.declName)
        if let call = node.parent?.as(FunctionCallExprSyntax.self), call.calledExpression.id == node.id {
            occurrences.append(Occurrence(sym: name, kind: "modifier", line: ln, col: col,
                endLine: callEndLine(call),
                implicit: node.base == nil, args: call.arguments.map { $0.label?.text ?? "_" },
                trailingClosure: call.trailingClosure != nil || !call.additionalTrailingClosures.isEmpty,
                attach: nil, prop: nil, scope: scope, src: callHead(".\(name)", call)))
        } else {
            occurrences.append(Occurrence(sym: name, kind: "member", line: ln, col: col,
                implicit: node.base == nil, args: nil, trailingClosure: nil,
                attach: nil, prop: nil, scope: scope, src: srcLine(ln)))
        }
        return .visitChildren
    }

    // MARK: type construction  VStack { } / Text("…") / List<Item>()
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        var ref = node.calledExpression.as(DeclReferenceExprSyntax.self)
        if ref == nil, let gen = node.calledExpression.as(GenericSpecializationExprSyntax.self) {
            ref = gen.expression.as(DeclReferenceExprSyntax.self)   // List<Item>() / ForEach<…>()
        }
        if let ref, let f = ref.baseName.text.first, f.isUppercase {
            let name = ref.baseName.text; let (ln, col) = loc(ref)
            occurrences.append(Occurrence(sym: name, kind: "type", line: ln, col: col,
                endLine: callEndLine(node), implicit: nil,
                args: node.arguments.map { $0.label?.text ?? "_" },
                trailingClosure: node.trailingClosure != nil || !node.additionalTrailingClosures.isEmpty,
                attach: nil, prop: nil, scope: scope, src: callHead(name, node)))
        }
        return .visitChildren
    }

    // MARK: key paths  \.dismiss  in .environment(\.dismiss, …) / @Environment(\.dismiss)
    override func visit(_ node: KeyPathExprSyntax) -> SyntaxVisitorContinueKind {
        var last: String? = nil
        for comp in node.components {
            if case let .property(p) = comp.component { last = p.declName.baseName.text }
        }
        if let key = last {
            let (ln, col) = loc(node)
            occurrences.append(Occurrence(sym: key, kind: "keypath", line: ln, col: col, implicit: nil,
                args: nil, trailingClosure: nil, attach: nil, prop: nil, scope: scope, src: srcLine(ln)))
        }
        return .visitChildren
    }

    // MARK: macros  #Preview { }
    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind { macro(node.macroName.text, node); return .visitChildren }
    override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind { macro(node.macroName.text, node); return .visitChildren }
    private func macro(_ name: String, _ node: some SyntaxProtocol) {
        let (ln, col) = loc(node)
        occurrences.append(Occurrence(sym: name, kind: "macro", line: ln, col: col, implicit: nil,
            args: nil, trailingClosure: nil, attach: nil, prop: nil, scope: scope, src: srcLine(ln)))
    }

    // MARK: property wrappers / attributes on bindings (handles multi-binding + let/var)
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let attrs = attributeNames(node.attributes)
        let isLet = node.bindingSpecifier.text == "let"
        let retType = node.bindings.first?.typeAnnotation?.type.trimmedDescription ?? ""
        // inventory view-builder computed props (body / some View vars)
        if Self.viewReturns.contains(where: { retType.contains($0) }),
           let nm = node.bindings.first?.pattern.trimmedDescription {
            let (ln, _) = loc(node)
            decls.append(Decl(name: nm, kind: "viewbuilder", conforms: [], line: ln,
                attributes: attrs.map { $0.0 }, wrappers: [], scope: scope, via: nil))
        }
        guard !attrs.isEmpty else { return .visitChildren }
        for b in node.bindings {
            let prop = PropInfo(name: b.pattern.trimmedDescription,
                                type: b.typeAnnotation?.type.trimmedDescription,
                                initText: shorten(b.initializer?.value.trimmedDescription))
            for (name, argText, attrNode) in attrs {
                let (ln, col) = loc(attrNode)
                occurrences.append(Occurrence(sym: name, kind: "attribute", line: ln, col: col,
                    implicit: nil, args: argText.map { [$0] }, trailingClosure: nil,
                    attach: isLet ? "let" : "var", prop: prop, scope: scope, src: srcLine(ln)))
            }
        }
        return .visitChildren
    }

    // MARK: function attributes + view-builder funcs
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        emitDeclAttributes(node.attributes, attach: "func")
        let ret = node.signature.returnClause?.type.trimmedDescription ?? ""
        if Self.viewReturns.contains(where: { ret.contains($0) }) {
            let (ln, _) = loc(node.name)
            decls.append(Decl(name: node.name.text, kind: "viewbuilder", conforms: [], line: ln,
                attributes: attributeNames(node.attributes).map { $0.0 }, wrappers: [], scope: scope, via: nil))
        }
        return .visitChildren
    }

    // MARK: declarations — push/pop scope, record components & attributes
    override func visit(_ n: StructDeclSyntax) -> SyntaxVisitorContinueKind { enter(n.name.text); recordDecl(n.name.text,"struct",n.inheritanceClause,n.attributes,n.memberBlock,n.name,nil); return .visitChildren }
    override func visitPost(_ n: StructDeclSyntax) { leave() }
    override func visit(_ n: ClassDeclSyntax) -> SyntaxVisitorContinueKind { enter(n.name.text); recordDecl(n.name.text,"class",n.inheritanceClause,n.attributes,n.memberBlock,n.name,nil); return .visitChildren }
    override func visitPost(_ n: ClassDeclSyntax) { leave() }
    override func visit(_ n: EnumDeclSyntax) -> SyntaxVisitorContinueKind { enter(n.name.text); recordDecl(n.name.text,"enum",n.inheritanceClause,n.attributes,n.memberBlock,n.name,nil); return .visitChildren }
    override func visitPost(_ n: EnumDeclSyntax) { leave() }
    override func visit(_ n: ActorDeclSyntax) -> SyntaxVisitorContinueKind { enter(n.name.text); recordDecl(n.name.text,"actor",n.inheritanceClause,n.attributes,n.memberBlock,n.name,nil); return .visitChildren }
    override func visitPost(_ n: ActorDeclSyntax) { leave() }
    override func visit(_ n: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = baseName(n.extendedType.trimmedDescription)
        enter(name)
        emitDeclAttributes(n.attributes, attach: "extension")
        recordDecl(name, "extension", n.inheritanceClause, AttributeListSyntax([]), n.memberBlock, n.extendedType, "extension")
        return .visitChildren
    }
    override func visitPost(_ n: ExtensionDeclSyntax) { leave() }

    private func enter(_ name: String) { stack.append(name) }
    private func leave() { if !stack.isEmpty { stack.removeLast() } }

    private func emitDeclAttributes(_ attrs: AttributeListSyntax, attach: String) {
        for (an, argText, attrNode) in attributeNames(attrs) {
            let (ln, col) = loc(attrNode)
            occurrences.append(Occurrence(sym: an, kind: "attribute", line: ln, col: col, implicit: nil,
                args: argText.map { [$0] }, trailingClosure: nil, attach: attach, prop: nil,
                scope: scope, src: srcLine(ln)))
        }
    }

    private func recordDecl(_ name: String, _ declKind: String, _ inheritance: InheritanceClauseSyntax?,
                            _ attributes: AttributeListSyntax, _ members: MemberBlockSyntax,
                            _ anchor: some SyntaxProtocol, _ via: String?) {
        let conforms = inheritance?.inheritedTypes.map { $0.type.trimmedDescription } ?? []
        emitDeclAttributes(attributes, attach: declKind)   // @Observable/@main/@MainActor on the type
        var kind: String? = nil
        for c in conforms {
            let base = baseName(c)
            if let k = Self.conformanceKind[base] { kind = k; break }
            if base.hasSuffix("Style") { kind = "style"; break }   // deterministic: stop on first style
        }
        guard let k = kind else { return }
        var wrappers: Set<String> = []
        for m in members.members {
            if let v = m.decl.as(VariableDeclSyntax.self) {
                for (wn, _, _) in attributeNames(v.attributes) { wrappers.insert(wn) }
            }
        }
        let (ln, _) = loc(anchor)
        // scope for a component = the enclosing type ABOVE it (stack minus self, which we just pushed)
        let enclosing = stack.count >= 2 ? stack[stack.count-2] : nil
        decls.append(Decl(name: name, kind: k, conforms: conforms, line: ln,
            attributes: attributeNames(attributes).map { $0.0 }, wrappers: wrappers.sorted(),
            scope: enclosing, via: via))
    }

    /// (attributeName, firstArgumentText?, attributeNode) for each @attribute (skips #if).
    private func attributeNames(_ list: AttributeListSyntax) -> [(String, String?, AttributeSyntax)] {
        var out: [(String, String?, AttributeSyntax)] = []
        for el in list {
            guard case let .attribute(attr) = el else { continue }
            let name = baseName(attr.attributeName.trimmedDescription)
            let argText = attr.arguments.map { shorten($0.trimmedDescription) ?? "" }
            out.append((name, argText, attr))
        }
        return out
    }

    private func shorten(_ s: String?) -> String? {
        guard var s = s else { return nil }
        s = s.replacingOccurrences(of: "\n", with: " ")
        if s.count > 120 { s = String(s.prefix(120)) }
        return s
    }
}
