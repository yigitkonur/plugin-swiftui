import Foundation

// Semantic exit codes (agentic-cli contract): stdout=data, stderr=operator, exit=class.
enum ExitClass: Int32 {
    case ok = 0, usage = 2, notFound = 3, network = 4, noData = 5
}

struct CtxError: Error {
    let cls: String        // error.class
    let code: String
    let message: String
    let retryable: Bool
    let suggestion: String?
    let exit: ExitClass
}

func die(_ e: CtxError, json: Bool) -> Never {
    if json {
        let env: [String: Any] = ["ok": false, "schema_version": "v1", "result": NSNull(),
            "next_actions": [],
            "error": ["class": e.cls, "code": e.code, "message": e.message,
                      "retryable": e.retryable, "suggestion": e.suggestion ?? NSNull()]]
        FileHandle.standardOutput.write(jsonData(env))
        FileHandle.standardOutput.write("\n".data(using: .utf8)!)
    } else {
        FileHandle.standardError.write("error[\(e.code)]: \(e.message)\n".data(using: .utf8)!)
        if let s = e.suggestion { FileHandle.standardError.write("  try: \(s)\n".data(using: .utf8)!) }
    }
    exit(e.exit.rawValue)
}

func jsonData(_ obj: Any) -> Data {
    (try? JSONSerialization.data(withJSONObject: obj,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])) ?? Data("{}".utf8)
}

// next_actions are literal follow-up commands the agent can run (the steering loop).
struct NextAction { let cmd: String; let why: String }

func emit(result: Any, next: [NextAction], json: Bool, render: () -> String) {
    if json {
        let env: [String: Any] = ["ok": true, "schema_version": "v1", "result": result,
            "next_actions": next.map { ["cmd": $0.cmd, "why": $0.why] }, "error": NSNull()]
        FileHandle.standardOutput.write(jsonData(env))
        FileHandle.standardOutput.write("\n".data(using: .utf8)!)
    } else {
        var s = render()
        if !next.isEmpty {
            s += "\n\nNext:\n" + next.map { "  $ \($0.cmd)   # \($0.why)" }.joined(separator: "\n")
        }
        print(s)
    }
}

// stderr logging (never pollutes the stdout data channel)
func note(_ s: String) { FileHandle.standardError.write("\(s)\n".data(using: .utf8)!) }
