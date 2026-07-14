import Foundation
import XCTest
@testable import TaskAI

final class OpenAICompatibleClientTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.handler = nil
        super.tearDown()
    }

    func testBuildsRequestAndDecodesProposal() async throws {
        let taskID = UUID()
        let proposal = PlanProposal(
            summary: "Plan",
            changes: [
                ProposedTaskChange(taskID: taskID, dueAt: Date(timeIntervalSince1970: 2_000), estimatedMinutes: 30, addedSubtasks: ["A"], reason: "focus")
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let proposalJSON = try encoder.encode(proposal)
        let proposalText = String(data: proposalJSON, encoding: .utf8)!
        let chatJSON = """
        {"choices":[{"message":{"content":\(jsonString(proposalText))}}]}
        """.data(using: .utf8)!

        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/chat/completions")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(object?["model"] as? String, "model-a")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, chatJSON)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let client = OpenAICompatibleClient(
            configuration: try AIServiceConfiguration(baseURL: URL(string: "https://api.example.com/v1")!, model: "model-a"),
            apiKeyStore: InMemoryAPIKeyStore(value: "test-key"),
            session: session
        )
        let result = try await client.proposePlan(
            PlanningRequest(
                tasks: [
                    PlanningTask(id: taskID, title: "T", details: "", subtasks: [], urgency: 1, importance: 2, dueAt: nil, estimatedMinutes: nil)
                ],
                capacityMinutes: 480,
                rangeStart: Date(timeIntervalSince1970: 1_000),
                rangeEnd: Date(timeIntervalSince1970: 10_000)
            )
        )
        XCTAssertEqual(result.summary, "Plan")
        XCTAssertEqual(result.changes.first?.taskID, taskID)
    }

    func testMapsAuthError() async {
        URLProtocolStub.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let client = OpenAICompatibleClient(
            configuration: try! AIServiceConfiguration(baseURL: URL(string: "https://api.example.com/v1")!, model: "model-a"),
            apiKeyStore: InMemoryAPIKeyStore(value: "test-key"),
            session: session
        )
        do {
            _ = try await client.proposePlan(
                PlanningRequest(tasks: [], capacityMinutes: 1, rangeStart: .now, rangeEnd: .now.addingTimeInterval(1))
            )
            XCTFail("expected error")
        } catch let error as AIClientError {
            XCTAssertEqual(error, .authentication)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    private func jsonString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
