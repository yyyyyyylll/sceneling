import Foundation

enum SSEEvent {
    case textDelta(String)
    case textFull(String)
    case audio(url: String, text: String)
    case done
    case error(String)
}

class SSEClient: NSObject, URLSessionDataDelegate {
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var buffer = Data()

    private var onEvent: ((SSEEvent) -> Void)?
    private var onComplete: (() -> Void)?

    func connect(
        url: URL,
        body: Data,
        token: String?,
        onEvent: @escaping (SSEEvent) -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.onEvent = onEvent
        self.onComplete = onComplete

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300

        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = body

        dataTask = session?.dataTask(with: request)
        dataTask?.resume()
    }

    func disconnect() {
        dataTask?.cancel()
        session?.invalidateAndCancel()
        dataTask = nil
        session = nil
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        processBuffer()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.onEvent?(.error(error.localizedDescription))
            }
        }
        DispatchQueue.main.async {
            self.onComplete?()
        }
    }

    // MARK: - Private

    private func processBuffer() {
        let delimiter = Data([0x0A, 0x0A]) // "\n\n"

        while let range = buffer.range(of: delimiter) {
            let eventData = buffer.subdata(in: 0..<range.lowerBound)
            buffer.removeSubrange(0..<range.upperBound)

            if eventData.isEmpty {
                continue
            }

            guard let eventText = String(data: eventData, encoding: .utf8) else { continue }
            processEventBlock(eventText)
        }
    }

    private func processEventBlock(_ eventBlock: String) {
        let lines = eventBlock.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("data:") {
                let jsonString = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)

                if let data = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let type = json["type"] as? String {

                    let event: SSEEvent
                    switch type {
                    case "text_delta":
                        let content = json["content"] as? String ?? ""
                        event = .textDelta(content)
                    case "text_full":
                        let content = json["content"] as? String ?? ""
                        event = .textFull(content)

                    case "audio":
                        let url = json["url"] as? String ?? ""
                        let audioText = json["text"] as? String ?? ""
                        print("[SSEClient] Received audio event, URL length: \(url.count), text: \(audioText.prefix(30))")
                        event = .audio(url: url, text: audioText)

                    case "done":
                        event = .done

                    case "error":
                        let content = json["content"] as? String ?? "Unknown error"
                        event = .error(content)

                    default:
                        continue
                    }

                    DispatchQueue.main.async {
                        self.onEvent?(event)
                    }
                }
            }
        }
    }
}
